class PagesController < ApplicationController
  allow_unauthenticated_access only: :home

  def home
    return render :landing, layout: "application" unless authenticated?

    @range = NetWorthHistory::RANGES.key?(params[:range]) ? params[:range] : NetWorthHistory::DEFAULT_RANGE
    start = NetWorthHistory.range_start(@range)
    @history = NetWorthHistory.new(SampleData.snapshots.select { |snapshot| snapshot.date >= start })
  end
end
