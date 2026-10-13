# A spending limit for a week (Monday to Sunday) or a statement month (each
# card's statement period), over any mix of categories and merchants: a
# purchase counts if it's in one of the categories or from one of the
# merchants. Refunds lower the spending; card payments, transfers and income
# never count. Budgets can overlap. With rollover, what's left of a period's
# limit is added to the next one's (going over doesn't take any away).
class Budget < ApplicationRecord
  PERIODS = { "weekly" => "Weekly", "monthly" => "Monthly" }.freeze
  ALERT_THRESHOLDS = [ 50, 90, 100 ].freeze
  NOT_SPENDING = %w[ LOAN_PAYMENTS TRANSFER_IN TRANSFER_OUT INCOME ].freeze
  CATEGORIES = (Transaction::CATEGORIES - NOT_SPENDING).freeze
  # Spending this much faster than the period is passing (in percentage points) counts as over pace.
  PACE_MARGIN = 10

  # A period's numbers. `limit`: the budget's amount plus anything rolled over
  # into it (`carried`). `elapsed_percent`: how much of the period has passed,
  # today included.
  Status = Data.define(:limit, :carried, :spent, :starts_on, :resets_on, :today) do
    def percent = (spent / limit * 100).to_f
    def remaining = limit - spent
    def elapsed_percent = ((today - starts_on + 1) * 100.0 / (resets_on - starts_on)).clamp(0, 100)

    def over? = spent > limit

    # :over (past the limit), :over_pace (spending faster than the period is passing) or :on_track.
    def state
      return :over if over?

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

  # Rollover counts from when it's turned on, not from the start of the data.
  before_save -> { self.rollover_started_on = (Date.current if rollover?) }, if: :rollover_changed?

  def weekly? = period == "weekly"

  # This period's numbers, or with `back`, a past period's (1 = the one before
  # this, and so on), judged at its end.
  def status(today: Date.current, back: 0) = statuses(back, today:)[back]

  # How the last `count` periods went, newest first, as far back as there are
  # transactions: [status, partial], where `partial` means the data starts
  # partway through that period. Past periods use the budget as it is now.
  def history(count, today: Date.current)
    first_date = Transaction.where(account: user.accounts.credit_cards).minimum(:date) or return []

    statuses(count, today:).drop(1)
      .take_while { |status| status.resets_on > first_date }
      .map { |status| [ status, status.starts_on < first_date ] }
  end

  # The numbers for this period and the `max_back` before it, this one first,
  # from one query. With rollover, each period after the one it was turned on
  # in gets what was left of the previous period's limit, never less than nothing.
  def statuses(max_back, today: Date.current)
    first_rollover = periods_back_to(rollover_started_on, today) if rollover? && rollover_started_on
    deepest = [ max_back, first_rollover.to_i ].max
    spent = spending_by_period(deepest, today)

    limits = {}
    carried = Hash.new(0)
    deepest.downto(0) do |back|
      carried[back] = [ limits[back + 1] - spent[back + 1], 0 ].max if first_rollover && back < first_rollover
      limits[back] = amount + carried[back]
    end

    (0..max_back).map do |back|
      starts_on, resets_on = period_dates(today, back)
      Status.new(limit: limits[back], carried: carried[back], spent: spent[back], starts_on:, resets_on:, today: back.zero? ? today : resets_on - 1)
    end
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
    # The spending in each period from this one (0) to `deepest` periods back,
    # from one query. Each card's transactions fall in that card's own periods.
    def spending_by_period(deepest, today)
      cards = user.accounts.credit_cards.index_by(&:id)
      totals = Hash.new(0)
      return totals if cards.empty?

      this_week = today.beginning_of_week(:monday)
      since = weekly? ? this_week - (deepest * 7) : cards.values.map { |card| card.statement_period_start(deepest, today:) }.min
      counted(Transaction.where(account: cards.values, date: since..)).pluck(:account_id, :date, :amount).each do |account_id, date, amount|
        back = weekly? ? (this_week - date.beginning_of_week(:monday)).to_i / 7 : (0..deepest).find { |n| date >= cards[account_id].statement_period_start(n, today:) }
        totals[back] += amount if back&.between?(0, deepest)
      end
      totals.transform_values! { |total| [ total, 0 ].max }
    end

    # Narrows `transactions` to the ones this budget counts: in one of its
    # categories or from one of its merchants, and not a payment or transfer.
    def counted(transactions)
      matches = []
      matches << self.class.sanitize_sql_array([ "#{Transaction::EFFECTIVE_CATEGORY_SQL} IN (?)", categories ]) if categories.any?
      matches << self.class.sanitize_sql_array([ "#{Transaction::MERCHANT_SQL} IN (?)", merchants ]) if merchants.any?
      transactions.where("(#{matches.join(" OR ")})")
        .where("#{Transaction::EFFECTIVE_CATEGORY_SQL} IS NULL OR #{Transaction::EFFECTIVE_CATEGORY_SQL} NOT IN (?)", NOT_SPENDING)
    end

    # How many periods back the one containing `date` is (0 = this one).
    def periods_back_to(date, today)
      return [ (today.beginning_of_week(:monday) - date.beginning_of_week(:monday)).to_i / 7, 0 ].max if weekly?

      (0..).find { |back| period_dates(today, back).first <= date }
    end

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
