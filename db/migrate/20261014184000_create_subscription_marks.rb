class CreateSubscriptionMarks < ActiveRecord::Migration[8.1]
  def change
    # What a user said about a subscription: confirmed a possible one, said one
    # isn't a subscription, or added one by hand (from the charge on `charged_on`).
    create_table :subscription_marks, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.string :merchant, null: false
      t.decimal :amount, precision: 19, scale: 4, null: false
      t.string :period, null: false
      t.date :charged_on
      t.timestamps
    end
    add_index :subscription_marks, [ :user_id, :merchant ]
  end
end
