# A spending limit for a week (Monday to Sunday) or a statement month (each
# card's statement period), over any mix of categories and merchants: a
# purchase counts if it's in one of the categories or from one of the
# merchants. Refunds lower the spending; card payments, transfers and income
# never count. Budgets can overlap.
class Budget < ApplicationRecord
  PERIODS = { "weekly" => "Weekly", "monthly" => "Monthly" }.freeze
  ALERT_THRESHOLDS = [ 50, 90, 100 ].freeze
  NOT_SPENDING = %w[ LOAN_PAYMENTS TRANSFER_IN TRANSFER_OUT INCOME ].freeze
  CATEGORIES = (Transaction::CATEGORIES - NOT_SPENDING).freeze
  # Spending this much faster than the period is passing (in percentage points) counts as over pace.
  PACE_MARGIN = 10

  # This period's numbers. `elapsed_percent`: how much of the period has passed, today included.
  Status = Data.define(:amount, :spent, :starts_on, :resets_on, :today) do
    def percent = (spent / amount * 100).to_f
    def remaining = amount - spent
    def elapsed_percent = ((today - starts_on + 1) * 100.0 / (resets_on - starts_on)).clamp(0, 100)

    def over? = spent > amount

    # :over (past the limit), :over_pace (spending faster than the period is passing) or :on_track.
    def state
      return :over if spent > amount

      percent > elapsed_percent + PACE_MARGIN ? :over_pace : :on_track
    end
  end

  belongs_to :user
  has_many :alerts, class_name: "BudgetAlert", dependent: :delete_all

  normalizes :name, with: ->(name) { name.squish }
  normalizes :categories, with: ->(categories) { categories.compact_blank.uniq }
  normalizes :merchants, with: ->(merchants) { merchants.map(&:strip).compact_blank.uniq }

  validates :name, presence: true, length: { maximum: 50 }
  validates :amount, numericality: { greater_than: 0, less_than: 10_000_000 }
  validates :period, inclusion: { in: PERIODS.keys }
  validate :counts_something
  validate :known_categories

  def weekly? = period == "weekly"

  # This period's numbers, or with `back`, a past period's (1 = the one before
  # this, and so on), judged at its end.
  def status(today: Date.current, back: 0)
    starts_on, resets_on = period_dates(today, back)
    Status.new(amount:, spent: [ transactions(today:, back:).sum(:amount), 0 ].max, starts_on:, resets_on:, today: back.zero? ? today : resets_on - 1)
  end

  # How the last `count` periods went, newest first, as far back as there are
  # transactions: [status, partial], where `partial` means the data starts
  # partway through that period. Past periods use the budget as it is now.
  def history(count, today: Date.current)
    first_date = Transaction.where(account: user.accounts.credit_cards).minimum(:date) or return []

    (1..count).lazy.map { |back| status(today:, back:) }
      .take_while { |status| status.resets_on > first_date }
      .map { |status| [ status, status.starts_on < first_date ] }.to_a
  end

  # The transactions that count toward the budget this period (or `back` periods ago).
  def transactions(today: Date.current, back: 0)
    cards = user.accounts.credit_cards.to_a
    in_period =
      if weekly?
        week = today.beginning_of_week(:monday) - (back * 7)
        Transaction.where(account: cards, date: week...(week + 7))
      else
        cards.map { |card| Transaction.where(account: card, date: card.statement_period_start(back, today:)...card.statement_period_start(back - 1, today:)) }
          .reduce(:or) || Transaction.none
      end

    matches = []
    matches << self.class.sanitize_sql_array([ "#{Transaction::EFFECTIVE_CATEGORY_SQL} IN (?)", categories ]) if categories.any?
    matches << self.class.sanitize_sql_array([ "#{Transaction::MERCHANT_SQL} IN (?)", merchants ]) if merchants.any?
    in_period.where("(#{matches.join(" OR ")})")
      .where("#{Transaction::EFFECTIVE_CATEGORY_SQL} IS NULL OR #{Transaction::EFFECTIVE_CATEGORY_SQL} NOT IN (?)", NOT_SPENDING)
  end

  # Emails the user when this period's spending first reaches 50%, 90% or
  # 100%: once per threshold per period, and only the highest when several are
  # reached at once. `silently` records them without emailing (e.g. for a
  # budget that's just been set up, already past some).
  def send_alerts!(silently: false, today: Date.current)
    status = status(today:)
    reached = ALERT_THRESHOLDS.select { |threshold| status.percent >= threshold }
    return if reached.empty?

    # Recorded atomically, so two checks running at once can't both email.
    rows = reached.map { |threshold| { budget_id: id, period_start: status.starts_on, threshold:, created_at: Time.current } }
    newly_reached = BudgetAlert.insert_all(rows, unique_by: %i[ budget_id period_start threshold ], returning: :threshold).rows.flatten
    BudgetsMailer.threshold(self, newly_reached.max).deliver_later if newly_reached.any? && !silently
  end

  # After the limit or what counts changes: forget this period's alerts, and
  # record the ones already reached without emailing.
  def reset_alerts!(today: Date.current)
    alerts.where(period_start: period_dates(today, 0).first).delete_all
    send_alerts!(silently: true, today:)
  end

  private
    # The first day of the period `back` periods ago (0 = this one) and the day
    # it resets. A statement month with several cards starts at the most recent
    # card's statement and resets at the next one; cards without a statement
    # date follow calendar months.
    def period_dates(today, back)
      if weekly?
        week = today.beginning_of_week(:monday) - (back * 7)
        return [ week, week + 7 ]
      end

      cards = user.accounts.credit_cards.to_a
      return [ today.beginning_of_month << back, today.beginning_of_month << (back - 1) ] if cards.empty?

      [ cards.map { |card| card.statement_period_start(back, today:) }.max, cards.map { |card| card.statement_period_start(back - 1, today:) }.min ]
    end

    def counts_something
      errors.add(:base, "Pick at least one category or merchant") if categories.empty? && merchants.empty?
    end

    def known_categories
      errors.add(:categories, "include one that can't be budgeted") if (categories - CATEGORIES).any?
    end
end
