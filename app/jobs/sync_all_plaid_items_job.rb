# Runs daily (config/recurring.yml): queues a balance sync for every Plaid connection.
class SyncAllPlaidItemsJob < ApplicationJob
  queue_as :default

  def perform
    PlaidItem.find_each { |plaid_item| SyncPlaidItemJob.perform_later(plaid_item) }
  end
end
