class PagesController < ApplicationController
  allow_unauthenticated_access only: :home

  def home
    return render :landing, layout: "application" unless authenticated?

    @range = NetWorthHistory::RANGES.key?(params[:range]) ? params[:range] : NetWorthHistory::DEFAULT_RANGE
    @view = params[:view] == "categories" ? "categories" : "net_worth"
    start = NetWorthHistory.range_start(@range)

    accounts = Current.user.accounts.includes(:plaid_item).to_a
    # Until real accounts are connected, the dashboard shows sample data.
    @sample = accounts.empty?
    if @sample
      @breakdown = NetWorthBreakdown.new(SampleData::ACCOUNTS)
      @history = NetWorthHistory.new(SampleData.snapshots.select { |snapshot| snapshot.date >= start })
    else
      @breakdown = NetWorthBreakdown.new(accounts.select(&:shown_on_dashboard?))
      @history = NetWorthHistory.new(Current.user.balance_snapshots.includes(:account).where(date: start..))
      @spent_this_month = SpendingBreakdown.new(Transaction.in_statement_periods(Current.user.accounts.credit_cards.to_a)).total
      @budget_statuses = Current.user.budgets.map(&:status)
    end
  end
end
