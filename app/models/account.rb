# An individual account (checking, credit card, brokerage, ...) within a PlaidItem.
class Account < ApplicationRecord
  belongs_to :plaid_item
  has_many :transactions, dependent: :destroy
  has_many :balance_snapshots, class_name: "AccountBalanceSnapshot", dependent: :destroy

  validates :plaid_account_id, presence: true, uniqueness: true
  validates :name, :account_type, presence: true

  delegate :institution_name, to: :plaid_item

  # Plaid's current balance; for credit cards, the amount owed.
  def balance = current_balance || 0

  # Saves today's balance (replacing an earlier one from the same day).
  def record_balance_snapshot(on:)
    return if current_balance.nil?

    balance_snapshots.find_or_initialize_by(date: on).update!(balance: current_balance)
  end
end
