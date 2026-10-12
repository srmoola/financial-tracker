# An individual account (checking, credit card, brokerage, ...) within a PlaidItem.
class Account < ApplicationRecord
  belongs_to :plaid_item
  has_many :transactions, dependent: :destroy
  has_many :balance_snapshots, class_name: "AccountBalanceSnapshot", dependent: :destroy

  validates :plaid_account_id, presence: true, uniqueness: true
  validates :name, :account_type, presence: true
end
