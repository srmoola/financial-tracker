# Credit card spending by Plaid category (personal_finance_category.primary).
# Only purchases count (positive amounts, Plaid's "money out"), so card
# payments and refunds aren't treated as spending. The largest categories get
# their own slice; the rest are folded into "Other" to keep the donut readable.
class SpendingBreakdown
  Category = Data.define(:key, :label, :total, :count) do
    # How the category appears in URLs (?category=...).
    def param = SpendingBreakdown.param_for(key)
  end

  MAX_NAMED_CATEGORIES = 5
  LABELS = {
    "FOOD_AND_DRINK" => "Food & drink",
    "GENERAL_MERCHANDISE" => "Shopping",
    "GENERAL_SERVICES" => "Services",
    "RENT_AND_UTILITIES" => "Rent & utilities",
    "HOME_IMPROVEMENT" => "Home improvement",
    "PERSONAL_CARE" => "Personal care",
    "GOVERNMENT_AND_NON_PROFIT" => "Government & nonprofit",
    "LOAN_PAYMENTS" => "Loan payments",
    "BANK_FEES" => "Bank fees",
    "TRANSFER_IN" => "Transfers in",
    "TRANSFER_OUT" => "Transfers out"
  }.freeze

  attr_reader :categories, :total, :purchase_count

  # `transactions` is a Transaction relation (already limited to the accounts and dates wanted).
  def initialize(transactions)
    purchases = transactions.where("amount > 0")
    totals = purchases.group(:category).sum(:amount)
    counts = purchases.group(:category).count

    named, rest = totals.sort_by { |category, total| [ -total, category.to_s ] }.partition.with_index { |_, index| index < MAX_NAMED_CATEGORIES }
    @categories = named.map { |category, total| Category.new(key: category, label: self.class.label_for(category), total:, count: counts[category]) }
    if rest.any?
      @categories << Category.new(key: :other, label: "Other", total: rest.sum(&:last), count: rest.sum { |category, _| counts[category] })
    end

    @total = totals.values.sum
    @purchase_count = counts.values.sum
  end

  def self.param_for(key)
    case key
    when :other then "other"
    when nil then "uncategorized"
    else key
    end
  end

  # Narrows `transactions` to one slice's category (given as its param).
  # "other" is everything without a slice of its own.
  def filter(transactions, param)
    named = categories.map(&:key) - [ :other ]

    case param
    when "other"
      others = transactions.where.not(category: named.compact)
      named.include?(nil) ? others : others.or(transactions.where(category: nil))
    when "uncategorized" then transactions.where(category: nil)
    else transactions.where(category: param)
    end
  end

  def self.label_for(category)
    return "Uncategorized" if category.blank?

    LABELS.fetch(category) { category.humanize }
  end
end
