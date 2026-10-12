# Credit card transactions: a spending summary and a paginated list, both for
# the chosen time range.
class TransactionsController < ApplicationController
  PER_PAGE = 25
  DEFAULT_RANGE = "1m"

  def index
    @range = NetWorthHistory::RANGES.key?(params[:range]) ? params[:range] : DEFAULT_RANGE
    @credit_cards = Current.user.accounts.credit_cards.to_a
    return if @credit_cards.empty?

    in_range = Transaction.where(account: @credit_cards).where(date: NetWorthHistory.range_start(@range)..)
    @spending = SpendingBreakdown.new(in_range)
    @any_transactions = Transaction.where(account: @credit_cards).exists?

    @total_count = in_range.count
    @page_count = [ (@total_count / PER_PAGE.to_f).ceil, 1 ].max
    @page = params[:page].to_i.clamp(1, @page_count)
    @transactions = in_range.includes(account: :plaid_item)
      .order(date: :desc, datetime: :desc, created_at: :desc, id: :desc)
      .offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
  end
end
