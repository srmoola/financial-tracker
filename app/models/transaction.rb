# A transaction on an Account, synced from Plaid. Positive amounts are money out.
class Transaction < ApplicationRecord
  belongs_to :account

  validates :plaid_transaction_id, presence: true, uniqueness: true
  validates :amount, :date, presence: true

  # Each card's transactions since its own statement period `periods_back`
  # statements ago began (0 = since its current statement period began).
  def self.in_statement_periods(cards, periods_back: 0)
    cards.map { |card| where(account: card, date: card.statement_period_start(periods_back)..) }.reduce(:or) || none
  end
end
