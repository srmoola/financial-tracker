# One connection's result in the daily sync (SyncAllPlaidItemsJob): whether it
# synced, and if not, why. Shown on the sync history page.
class DailySync < ApplicationRecord
  # A day on the sync history page: :succeeded, :failed (with the failed
  # syncs), :missed (the daily job didn't run) or :pending (today, not run yet).
  Day = Data.define(:date, :status, :ran_at, :bank_count, :failures)

  # The daily sync runs at 6:00 UTC (config/recurring.yml); until an hour
  # after that, today counts as not run yet rather than missed.
  MISSED_AFTER_HOUR_UTC = 7

  belongs_to :plaid_item

  scope :owned_by, ->(user) { joins(:plaid_item).where(plaid_items: { user_id: user.id }) }

  # The user's last `days` days, newest first, back to their first daily sync.
  # Each connection counts by its last attempt that day.
  def self.days_for(user, days: 30, now: Time.current)
    today = now.to_date
    first = owned_by(user).minimum(:created_at)&.to_date or return []
    start = [ first, today - (days - 1) ].max
    by_date = owned_by(user).includes(:plaid_item).where(created_at: start.beginning_of_day..).order(:created_at).group_by { |sync| sync.created_at.to_date }

    today.downto(start).map do |date|
      latest = by_date.fetch(date, []).index_by(&:plaid_item_id).values
      if latest.empty?
        pending = date == today && now.utc.hour < MISSED_AFTER_HOUR_UTC
        Day.new(date:, status: pending ? :pending : :missed, ran_at: nil, bank_count: 0, failures: [])
      else
        failures = latest.reject(&:succeeded)
        Day.new(date:, status: failures.any? ? :failed : :succeeded, ran_at: latest.map(&:created_at).min, bank_count: latest.size, failures:)
      end
    end
  end

  # What went wrong, for the history page: Plaid's error code (e.g.
  # ITEM_LOGIN_REQUIRED) or the error's class.
  def self.error_for(error)
    (PlaidClient.error_code(error) if error.is_a?(Plaid::ApiError)) || error.class.name
  end
end
