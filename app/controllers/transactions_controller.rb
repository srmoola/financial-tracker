# Credit card transactions: a spending summary (donut), a spending chart and a
# paginated list, each with its own time range. The list can be filtered to a
# category (from its own menu, or a category picked on the donut) and searched;
# the chart always shows every category.
class TransactionsController < ApplicationController
  PER_PAGE = 25
  RANGES = { "1w" => "1W", "statement" => "This month", "1m" => "1M", "3m" => "3M", "6m" => "6M", "1y" => "1Y", "all" => "All" }.freeze
  # "1w" is the last 7 days, today included, for every card.
  WEEK_DAYS = 7
  # The other ranges follow each card's statements: how many full statements before the current
  # period to include. "1w" and "all" aren't here: they don't follow statements.
  STATEMENTS_BACK = { "statement" => 0, "1m" => 1, "3m" => 3, "6m" => 6, "1y" => 12 }.freeze
  DEFAULT_RANGE = "statement" # each card's current statement period
  DEFAULT_CHART_RANGE = "6m"
  DEFAULT_LIST_RANGE = "statement"

  helper_method :transactions_path_with

  # The first day of the "1w" range.
  def self.week_start(today = Date.current) = today - (WEEK_DAYS - 1)

  def index
    @range = RANGES.key?(params[:range]) ? params[:range] : DEFAULT_RANGE # the donut's
    @list_range = RANGES.key?(params[:list_range]) ? params[:list_range] : DEFAULT_LIST_RANGE
    @chart_range = RANGES.key?(params[:chart_range]) ? params[:chart_range] : DEFAULT_CHART_RANGE
    @spending_view = params[:spending_view] == "categories" ? "categories" : "total"
    @category = params[:category].presence
    @query = params[:q].to_s.squish.presence
    @credit_cards = Current.user.accounts.credit_cards.includes(:plaid_item).to_a
    @plaid_items_needing_consent = Current.user.plaid_items.where(statement_dates_status: "needs_consent").to_a
    return if @credit_cards.empty?

    all_transactions = Transaction.where(account: @credit_cards)
    @earliest_date = all_transactions.minimum(:date) if "all".in?([ @range, @list_range ])
    @spending = SpendingBreakdown.new(transactions_in(@range))
    @any_transactions = all_transactions.exists?

    in_list_range = transactions_in(@list_range)
    listed = @category ? @spending.filter(in_list_range, @category) : in_list_range
    listed = search(listed, @query) if @query
    # The list's category menu: every category in the list's range, plus the
    # current filter if it isn't one of them (e.g. the donut's Other).
    @category_options = in_list_range.with_parts.distinct.pluck(Arel.sql(Transaction::PART_CATEGORY_SQL))
      .map { |category| [ SpendingBreakdown.label_for(category), SpendingBreakdown.param_for(category) ] }.sort
    if @category && @category_options.none? { |_, param| param == @category }
      @category_options << [ @category == "other" ? "Other categories" : SpendingBreakdown.label_for(@category == "uncategorized" ? nil : @category), @category ]
    end

    # Grouped into the donut's categories, so each category keeps its color.
    @spending_history = SpendingHistory.new(
      transactions_in(@chart_range).where("transactions.amount > 0"), cards: @credit_cards,
      category_keys: @spending.categories.map(&:key) - [ :other ], periods_back: STATEMENTS_BACK[@chart_range],
      since: (self.class.week_start if @chart_range == "1w")
    )

    @total_count = listed.count
    @page_count = [ (@total_count / PER_PAGE.to_f).ceil, 1 ].max
    @page = params[:page].to_i.clamp(1, @page_count)
    @transactions = listed.includes(:splits, account: :plaid_item)
      .order(date: :desc, datetime: :desc, created_at: :desc, id: :desc)
      .offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
  end

  # Changes a transaction's category (or resets it to Plaid's) and/or its note,
  # then re-renders the page in place.
  def update
    transaction = Transaction.owned_by(Current.user).find(params[:id])
    changes = {}
    if params.key?(:category)
      category = params[:category].presence
      changes[:category_override] = category == transaction.category ? nil : category # picking Plaid's own category is a reset
    end
    changes[:note] = params[:note].to_s if params.key?(:note)

    if transaction.update(changes)
      redirect_to return_path, status: :see_other
    else
      head :unprocessable_content
    end
  end

  private
    # A link back to this page, keeping every range, the chart's view and the
    # list's category except for `changes` (e.g. `chart_range: "1y"`).
    def transactions_path_with(**changes)
      transactions_path({ range: @range, list_range: @list_range, chart_range: @chart_range, spending_view: @spending_view, category: @category, q: @query }.merge(changes).compact)
    end

    # Transactions whose merchant, statement description or note contains `query` (any case).
    def search(transactions, query)
      pattern = "%#{Transaction.sanitize_sql_like(query)}%"
      transactions.where("transactions.merchant_name ILIKE :pattern OR transactions.description ILIKE :pattern OR transactions.note ILIKE :pattern", pattern:)
    end

    def transactions_in(range)
      if (periods_back = STATEMENTS_BACK[range])
        Transaction.in_statement_periods(@credit_cards, periods_back:)
      elsif range == "1w"
        Transaction.where(account: @credit_cards, date: self.class.week_start..)
      else
        Transaction.where(account: @credit_cards)
      end
    end

    # Back to the same range, filter and page the change was made from.
    def return_path
      path = params[:return_to].to_s
      path.start_with?("/transactions") ? path : transactions_path
    end
end
