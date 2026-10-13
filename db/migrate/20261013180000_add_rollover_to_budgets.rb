class AddRolloverToBudgets < ActiveRecord::Migration[8.1]
  def change
    add_column :budgets, :rollover, :boolean, default: false, null: false
    # When rollover was turned on: leftovers carry from the period after the one this falls in.
    add_column :budgets, :rollover_started_on, :date
  end
end
