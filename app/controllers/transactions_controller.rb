# Credit card transactions: a spending summary and a paginated list, both for
# the chosen time range, and a spending chart with its own range. Clicking a
# spending category filters the list and the chart to it.
class TransactionsController < ApplicationController
  PER_PAGE = 25
  RANGES = { "statement" => "This month", "1m" => "1M", "3m" => "3M", "6m" => "6M", "1y" => "1Y", "all" => "All" }.freeze
  # Ranges follow each card's statements: how many full statements before the current period to
  # include. "all" isn't here: it has no start date.
  STATEMENTS_BACK = { "statement" => 0, "1m" => 1, "3m" => 3, "6m" => 6, "1y" => 12 }.freeze
  DEFAULT_RANGE = "statement" # each card's current statement period
  DEFAULT_CHART_RANGE = "6m"

  def index
    @range = RANGES.key?(params[:range]) ? params[:range] : DEFAULT_RANGE
    @credit_cards = Current.user.accounts.credit_cards.includes(:plaid_item).to_a
    @plaid_items_needing_consent = Current.user.plaid_items.where(statement_dates_status: "needs_consent").to_a
    return if @credit_cards.empty?

    @statements_back = STATEMENTS_BACK[@range]
    in_range = transactions_in(@range)
    @earliest_date = in_range.minimum(:date) if @range == "all"
    @spending = SpendingBreakdown.new(in_range)
    @any_transactions = Transaction.where(account: @credit_cards).exists?

    @category = params[:category].presence
    listed = @category ? @spending.filter(in_range, @category) : in_range

    @spending_view = params[:spending_view] == "categories" ? "categories" : "total"
    @chart_range = RANGES.key?(params[:chart_range]) ? params[:chart_range] : DEFAULT_CHART_RANGE
    charted = transactions_in(@chart_range)
    charted = @spending.filter(charted, @category) if @category
    # Grouped into the donut's categories, so each category keeps its color.
    @spending_history = SpendingHistory.new(
      charted.where("amount > 0"), cards: @credit_cards,
      category_keys: @spending.categories.map(&:key) - [ :other ], periods_back: STATEMENTS_BACK[@chart_range]
    )

    @total_count = listed.count
    @page_count = [ (@total_count / PER_PAGE.to_f).ceil, 1 ].max
    @page = params[:page].to_i.clamp(1, @page_count)
    @transactions = listed.includes(account: :plaid_item)
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
    def transactions_in(range)
      if (periods_back = STATEMENTS_BACK[range])
        Transaction.in_statement_periods(@credit_cards, periods_back:)
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
