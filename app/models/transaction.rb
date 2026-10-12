# A transaction on an Account, synced from Plaid. Positive amounts are money out.
class Transaction < ApplicationRecord
  belongs_to :account

  validates :plaid_transaction_id, presence: true, uniqueness: true
  validates :amount, :date, presence: true

  # Each card's transactions since its own current statement period began.
  def self.in_current_statements(cards)
    cards.map { |card| where(account: card, date: card.current_statement_start..) }.reduce(:or) || none
  end
end
