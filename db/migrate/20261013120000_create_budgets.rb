class CreateBudgets < ActiveRecord::Migration[8.1]
  def change
    create_table :budgets, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.decimal :amount, precision: 19, scale: 4, null: false
      t.string :period, null: false
      t.string :categories, array: true, default: [], null: false
      t.string :merchants, array: true, default: [], null: false
      t.timestamps
    end

    # Which alert emails (50%, 90%, 100%) a budget has sent, once per period.
    create_table :budget_alerts, id: :uuid do |t|
      t.references :budget, null: false, foreign_key: true, type: :uuid
      t.date :period_start, null: false
      t.integer :threshold, null: false
      t.datetime :created_at, null: false
    end
    add_index :budget_alerts, [ :budget_id, :period_start, :threshold ], unique: true
  end
end
