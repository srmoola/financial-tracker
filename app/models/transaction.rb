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
  # A split purchase counts as its parts; anything else as one part. After
  # `with_parts` (one row per part), these are a part's category and amount.
  PART_CATEGORY_SQL = "COALESCE(transaction_splits.category, #{EFFECTIVE_CATEGORY_SQL})".freeze
  PART_AMOUNT_SQL = "COALESCE(transaction_splits.amount, transactions.amount)".freeze

  # Who a transaction is with: Plaid's merchant name, else the statement description.
  MERCHANT_SQL = "COALESCE(NULLIF(transactions.merchant_name, ''), transactions.description)".freeze

  NOTE_MAX_LENGTH = 280

  belongs_to :account
  has_many :splits, -> { order(amount: :desc) }, class_name: "TransactionSplit", dependent: :delete_all

  normalizes :note, with: ->(note) { note.strip.presence }

  validates :plaid_transaction_id, presence: true, uniqueness: true
  validates :amount, :date, presence: true
  validates :category_override, inclusion: { in: CATEGORIES }, allow_nil: true
  validates :note, length: { maximum: NOTE_MAX_LENGTH }

  scope :owned_by, ->(user) { joins(account: :plaid_item).where(plaid_items: { user_id: user.id }) }
  scope :with_parts, -> { joins("LEFT JOIN transaction_splits ON transaction_splits.transaction_id = transactions.id") }

  # Each card's transactions since its own statement period `periods_back`
  # statements ago began (0 = since its current statement period began).
  def self.in_statement_periods(cards, periods_back: 0)
    cards.map { |card| where(account: card, date: card.statement_period_start(periods_back)..) }.reduce(:or) || none
  end

  # Who a transaction is with, for grouping charges: Plaid's merchant name, else
  # the statement description without numbers and symbols (order numbers,
  # masked digits). Nil when nothing's left.
  def self.merchant_key(merchant_name, description)
    merchant_name.presence || description.to_s.gsub(/[^[:alpha:]&' .]+/, " ").squish.presence
  end

  def effective_category = category_override || category
  def split? = splits.any?

  # Splits a purchase into parts, each { category:, amount: } with at least two
  # parts, positive amounts adding up to the purchase. Returns false (with
  # `errors`) if they don't; an empty list removes the split.
  def split_into(parts)
    parts = parts.map { |part| { category: part[:category].presence, amount: BigDecimal(part[:amount].to_s.delete("$,").presence || "0").round(2) } }
    if parts.any?
      errors.add(:base, "Only purchases can be split") unless amount.positive?
      errors.add(:base, "Split into at least two parts") if parts.size < 2
      errors.add(:base, "Pick a category for every part") if parts.any? { |part| !part[:category].in?(CATEGORIES) }
      errors.add(:base, "Every part needs an amount") if parts.any? { |part| !part[:amount].positive? }
      errors.add(:base, "The parts must add up to #{ActiveSupport::NumberHelper.number_to_currency(amount)}") unless parts.sum { |part| part[:amount] } == amount.round(2)
      return false if errors.any?
    end

    transaction do
      splits.delete_all
      parts.each { |part| splits.create!(part) }
    end
    true
  end
  def recategorized? = category_override.present?

  # The name to show: Plaid's merchant name, otherwise the statement description,
  # unless the card masked it with asterisks (e.g. "*********-********").
  def display_name = merchant_name.presence || (description.presence unless masked_description?) || "Unknown merchant"

  # True when Plaid found no merchant and the card masked the description, so it
  # isn't a useful name.
  def masked_description? = merchant_name.blank? && description.to_s.include?("**")
end
