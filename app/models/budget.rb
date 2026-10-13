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

  def status(today: Date.current)
    starts_on, resets_on = period_dates(today)
    Status.new(amount:, spent: [ transactions(today:).sum(:amount), 0 ].max, starts_on:, resets_on:, today:)
  end

  # This period's transactions that count toward the budget.
  def transactions(today: Date.current)
    cards = user.accounts.credit_cards.to_a
    in_period = weekly? ? Transaction.where(account: cards, date: today.beginning_of_week(:monday)..) : Transaction.in_statement_periods(cards)

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
    alerts.where(period_start: period_dates(today).first).delete_all
    send_alerts!(silently: true, today:)
  end

  private
    # The period's first day and the day it resets. A statement month with
    # several cards starts at the most recent card's statement and resets at the
    # next one; cards without a statement date follow calendar months.
    def period_dates(today)
      return [ today.beginning_of_week(:monday), today.beginning_of_week(:monday) + 7 ] if weekly?

      starts = user.accounts.credit_cards.map { |card| card.current_statement_start(today:) }
      starts = [ today.beginning_of_month ] if starts.empty?
      [ starts.max, starts.map(&:next_month).min ]
    end

    def counts_something
      errors.add(:base, "Pick at least one category or merchant") if categories.empty? && merchants.empty?
    end

    def known_categories
      errors.add(:categories, "include one that can't be budgeted") if (categories - CATEGORIES).any?
    end
end
