# Refreshes one Plaid connection: balances (and today's snapshot) for every
# account, and transactions for credit cards. As part of the daily sync
# (`daily: true`), the result is recorded for the sync history page.
class SyncPlaidItemJob < ApplicationJob
  queue_as :default

  def perform(plaid_item, daily: false)
    plaid_item.sync!
    plaid_item.daily_syncs.create!(succeeded: true) if daily
  rescue => error
    plaid_item.daily_syncs.create!(succeeded: false, error: DailySync.error_for(error)) if daily
    raise
  end
end
