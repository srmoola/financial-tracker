# Refreshes one Plaid connection: balances (and today's snapshot) for every
# account, and transactions for credit cards.
class SyncPlaidItemJob < ApplicationJob
  queue_as :default

  def perform(plaid_item)
    plaid_item.sync!
  end
end
