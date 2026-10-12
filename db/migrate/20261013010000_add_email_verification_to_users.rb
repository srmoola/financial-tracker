class AddEmailVerificationToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :email_verified_at, :datetime
    add_column :users, :email_verification_code_digest, :string
    add_column :users, :email_verification_code_sent_at, :datetime
    add_column :users, :email_verification_attempts, :integer, default: 0, null: false

    # Everyone who signed up before verification existed counts as verified.
    up_only { execute "UPDATE users SET email_verified_at = created_at" }
  end
end
