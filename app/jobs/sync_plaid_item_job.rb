# Refreshes one Plaid connection's accounts and balances, and records today's snapshot.
class SyncPlaidItemJob < ApplicationJob
  queue_as :default

  def perform(plaid_item)
    plaid_item.sync_balances!
  end
end
