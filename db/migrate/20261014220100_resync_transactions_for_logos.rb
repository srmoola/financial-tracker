class ResyncTransactionsForLogos < ActiveRecord::Migration[8.1]
  # Starts each account's transaction sync over, so the next sync pulls in the
  # whole history again and fills in the logos and websites on the transactions
  # already saved (matched by their Plaid ID; categories, notes, splits and
  # budget exclusions the user set are kept).
  def up
    execute "UPDATE accounts SET transaction_sync_cursor = NULL"
  end

  def down
  end
end
