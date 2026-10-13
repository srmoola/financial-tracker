# What a user's Monday email says about last week (Monday to Sunday): the
# spending that came in, how their budgets stand this month, how their net
# worth moved, and any connection that failed to sync.
#
# "Came in" goes by when transactions arrived, not when they were bought:
# Capital One posts purchases days later, so by purchase date the end of each
# week would always be missing. This way every transaction shows up in one
# email. Only recent purchases count, so a newly connected bank's history
# isn't news.
class WeeklyDigest
  RECENT_PURCHASE_DAYS = 14
  BIGGEST_PURCHASES = 5
  TOP_CATEGORIES = 3

  attr_reader :user, :starts_on, :ends_on

  def initialize(user, today: Date.current)
    @user = user
    @starts_on = today.beginning_of_week(:monday) - 7
    @ends_on = @starts_on + 6
  end

  def worth_sending? = user.accounts.exists?

  # Purchases that came in last week (or, with `weeks_back`, the week before).
  def new_purchases(weeks_back: 0)
    starts_on = @starts_on - (7 * weeks_back)
    Transaction.where(account: user.accounts.credit_cards, created_at: starts_on.beginning_of_day...(starts_on + 7).beginning_of_day)
      .where("transactions.amount > 0").where(date: (starts_on - RECENT_PURCHASE_DAYS)..)
  end

  def spent = new_purchases.sum(:amount)
  def spent_the_week_before = new_purchases(weeks_back: 1).sum(:amount)
  def purchase_count = new_purchases.count
  def top_categories = SpendingBreakdown.new(new_purchases).categories.first(TOP_CATEGORIES)
  def biggest_purchases = new_purchases.order(amount: :desc).limit(BIGGEST_PURCHASES).to_a

  def budgets = user.budgets.order(:created_at).map { |budget| [ budget, budget.status ] }

  # How net worth moved from the end of the week before to the end of last
  # week, when there are balances for both days.
  def net_worth_change
    points = NetWorthHistory.new(user.balance_snapshots.includes(:account).where(date: [ starts_on - 1, ends_on ])).points
    [ points.last.net_worth - points.first.net_worth, points.last.net_worth ] if points.size == 2
  end

  # Connections whose daily sync failed last week: [plaid_item, error], the latest error each.
  def sync_failures
    DailySync.owned_by(user).includes(:plaid_item).where(succeeded: false, created_at: starts_on.beginning_of_day...(ends_on + 1).beginning_of_day)
      .order(:created_at).group_by(&:plaid_item).map { |plaid_item, syncs| [ plaid_item, syncs.last.error ] }
  end
end
