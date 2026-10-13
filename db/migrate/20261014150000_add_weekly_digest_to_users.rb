class AddWeeklyDigestToUsers < ActiveRecord::Migration[8.1]
  def change
    # The Monday summary email; on for everyone until they turn it off.
    add_column :users, :weekly_digest, :boolean, default: true, null: false
  end
end
