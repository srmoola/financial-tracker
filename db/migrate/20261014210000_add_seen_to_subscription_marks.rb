class AddSeenToSubscriptionMarks < ActiveRecord::Migration[8.1]
  def change
    # The user removed the subscription's "New" chip.
    add_column :subscription_marks, :seen, :boolean, default: false, null: false
  end
end
