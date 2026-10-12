class CreatePlaidItems < ActiveRecord::Migration[8.1]
  def change
    create_table :plaid_items, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :item_id, null: false # Plaid's item_id
      t.string :access_token, null: false # encrypted (see PlaidItem)
      t.string :institution_id
      t.string :institution_name
      t.datetime :last_synced_at

      t.timestamps
    end
    add_index :plaid_items, :item_id, unique: true
  end
end
