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
      @breakdown = NetWorthBreakdown.new(accounts)
      @history = NetWorthHistory.new(Current.user.balance_snapshots.includes(:account).where(date: start..))
      last_month = Transaction.where(account: Current.user.accounts.credit_cards, date: NetWorthHistory.range_start("1m")..)
      @spent_last_month = SpendingBreakdown.new(last_month).total
    end
  end
end
