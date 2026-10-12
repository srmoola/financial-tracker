# A transaction on an Account, synced from Plaid. Positive amounts are money out.
class Transaction < ApplicationRecord
  belongs_to :account

  validates :plaid_transaction_id, presence: true, uniqueness: true
  validates :amount, :date, presence: true
end
