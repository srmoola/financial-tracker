class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.string :plaid_transaction_id, null: false
      t.decimal :amount, precision: 19, scale: 4, null: false # Plaid convention: positive = money out, negative = money in
      t.string :currency_code
      t.string :merchant_name
      t.string :description
      t.date :date, null: false
      t.datetime :datetime
      t.boolean :pending, null: false, default: false
      t.string :pending_transaction_id
      t.string :category
      t.float :latitude
      t.float :longitude
      t.string :payment_channel

      t.timestamps
    end
    add_index :transactions, :plaid_transaction_id, unique: true
  end
end
