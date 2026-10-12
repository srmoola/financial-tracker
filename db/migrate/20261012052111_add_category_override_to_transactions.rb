class AddCategoryOverrideToTransactions < ActiveRecord::Migration[8.1]
  def change
    # The user's own category for a transaction. Plaid's stays in `category`, so syncs never overwrite the user's choice.
    add_column :transactions, :category_override, :string
  end
end
