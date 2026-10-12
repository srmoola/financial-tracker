class AddNoteToTransactions < ActiveRecord::Migration[8.1]
  def change
    # A short note the user adds to a transaction (Plaid never touches it).
    add_column :transactions, :note, :text
  end
end
