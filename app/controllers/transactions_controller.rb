# Credit card transactions: a spending summary and a paginated list, both for
# the chosen time range. Clicking a spending category filters the list to it.
class TransactionsController < ApplicationController
  PER_PAGE = 25
  RANGES = { "statement" => "This month", "1m" => "1M", "3m" => "3M", "6m" => "6M", "1y" => "1Y" }.freeze
  DEFAULT_RANGE = "statement" # each card's current statement period

  def index
    @range = RANGES.key?(params[:range]) ? params[:range] : DEFAULT_RANGE
    @credit_cards = Current.user.accounts.credit_cards.includes(:plaid_item).to_a
    @plaid_items_needing_consent = Current.user.plaid_items.where(statement_dates_status: "needs_consent").to_a
    return if @credit_cards.empty?

    in_range = @range == "statement" ? Transaction.in_current_statements(@credit_cards) : Transaction.where(account: @credit_cards, date: NetWorthHistory.range_start(@range)..)
    @spending = SpendingBreakdown.new(in_range)
    @any_transactions = Transaction.where(account: @credit_cards).exists?

    @category = params[:category].presence
    listed = @category ? @spending.filter(in_range, @category) : in_range

    @total_count = listed.count
    @page_count = [ (@total_count / PER_PAGE.to_f).ceil, 1 ].max
    @page = params[:page].to_i.clamp(1, @page_count)
    @transactions = listed.includes(account: :plaid_item)
      .order(date: :desc, datetime: :desc, created_at: :desc, id: :desc)
      .offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
  end
end
