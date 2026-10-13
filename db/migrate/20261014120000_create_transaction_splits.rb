class CreateTransactionSplits < ActiveRecord::Migration[8.1]
  def change
    # The parts of a purchase split across categories (e.g. groceries and household at Costco).
    create_table :transaction_splits, id: :uuid do |t|
      t.references :transaction, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.string :category, null: false
      t.decimal :amount, precision: 19, scale: 4, null: false
      t.timestamps
    end
  end
end
