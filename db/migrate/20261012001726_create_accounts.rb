class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts, id: :uuid do |t|
      t.references :plaid_item, null: false, foreign_key: true, type: :uuid
      t.string :plaid_account_id, null: false
      t.string :name, null: false
      t.string :account_type, null: false # Plaid's account "type" (depository, credit, investment, ...); `type` is reserved by Rails
      t.string :subtype
      t.string :mask
      t.string :currency_code
      t.decimal :current_balance, precision: 19, scale: 4 # for credit accounts, the amount owed
      t.decimal :available_balance, precision: 19, scale: 4
      t.decimal :credit_limit, precision: 19, scale: 4
      t.datetime :last_synced_at

      t.timestamps
    end
    add_index :accounts, :plaid_account_id, unique: true
  end
end
