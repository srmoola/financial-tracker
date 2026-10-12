# A transaction on an Account, synced from Plaid. Positive amounts are money out.
class Transaction < ApplicationRecord
  # Plaid's personal_finance_category.primary values, in the order the category picker lists them.
  CATEGORIES = %w[
    FOOD_AND_DRINK GENERAL_MERCHANDISE TRANSPORTATION TRAVEL ENTERTAINMENT PERSONAL_CARE MEDICAL
    GENERAL_SERVICES RENT_AND_UTILITIES HOME_IMPROVEMENT GOVERNMENT_AND_NON_PROFIT BANK_FEES
    LOAN_PAYMENTS TRANSFER_IN TRANSFER_OUT INCOME
  ].freeze

  # The category used everywhere: the user's choice if they made one, otherwise Plaid's.
  EFFECTIVE_CATEGORY_SQL = "COALESCE(transactions.category_override, transactions.category)".freeze

  belongs_to :account

  validates :plaid_transaction_id, presence: true, uniqueness: true
  validates :amount, :date, presence: true
  validates :category_override, inclusion: { in: CATEGORIES }, allow_nil: true

  scope :owned_by, ->(user) { joins(account: :plaid_item).where(plaid_items: { user_id: user.id }) }

  # Each card's transactions since its own statement period `periods_back`
  # statements ago began (0 = since its current statement period began).
  def self.in_statement_periods(cards, periods_back: 0)
    cards.map { |card| where(account: card, date: card.statement_period_start(periods_back)..) }.reduce(:or) || none
  end

  def effective_category = category_override || category
  def recategorized? = category_override.present?
end
