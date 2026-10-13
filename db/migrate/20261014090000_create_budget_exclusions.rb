class CreateBudgetExclusions < ActiveRecord::Migration[8.1]
  def change
    # A transaction that doesn't count toward a budget (e.g. a reimbursed dinner).
    create_table :budget_exclusions, id: :uuid do |t|
      t.references :budget, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :transaction, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.datetime :created_at, null: false
    end
    add_index :budget_exclusions, [ :budget_id, :transaction_id ], unique: true
  end
end
