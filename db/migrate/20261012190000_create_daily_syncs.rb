class CreateDailySyncs < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_syncs, id: :uuid do |t|
      t.references :plaid_item, null: false, foreign_key: true, type: :uuid
      t.boolean :succeeded, null: false
      t.string :error
      t.datetime :created_at, null: false
    end
    add_index :daily_syncs, [ :plaid_item_id, :created_at ]
  end
end
