# The daily sync's recent results for the user's connections, linked from the Accounts page.
class SyncHistoriesController < ApplicationController
  def show
    @days = DailySync.days_for(Current.user)
  end
end
