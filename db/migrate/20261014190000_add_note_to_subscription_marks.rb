class AddNoteToSubscriptionMarks < ActiveRecord::Migration[8.1]
  def change
    # A short note on a subscription, e.g. to tell apart two from the same merchant.
    add_column :subscription_marks, :note, :string
  end
end
