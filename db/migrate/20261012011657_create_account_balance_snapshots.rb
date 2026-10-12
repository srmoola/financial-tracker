class CreateAccountBalanceSnapshots < ActiveRecord::Migration[8.1]
  def change
    # One balance per account per day, recorded by the daily sync. Net worth history is computed from these.
    create_table :account_balance_snapshots, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid, index: false # covered by the unique index below
      t.date :date, null: false
      t.decimal :balance, precision: 19, scale: 4, null: false # the account's current_balance on that day

      t.timestamps
    end
    add_index :account_balance_snapshots, [ :account_id, :date ], unique: true
  end
end
