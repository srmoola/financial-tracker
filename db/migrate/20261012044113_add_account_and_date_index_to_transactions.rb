class AddAccountAndDateIndexToTransactions < ActiveRecord::Migration[8.1]
  def change
    # The Transactions page lists and totals each account's transactions over a date range.
    add_index :transactions, [ :account_id, :date ]
  end
end
