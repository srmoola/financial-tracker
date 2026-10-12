# Fake numbers for designing the dashboard before the Plaid integration exists.
# Delete this (and its uses in the views) once real accounts are synced.
module SampleData
  # Same shape as the Account model's columns (plus the institution from its PlaidItem).
  Account = Data.define(:name, :institution, :mask, :account_type, :subtype, :balance)
  Highlight = Data.define(:section, :stat, :detail)

  ACCOUNTS = [
    Account.new(name: "Everyday Checking", institution: "First Bank", mask: "4821", account_type: "depository", subtype: "checking", balance: BigDecimal("6240.12")),
    Account.new(name: "Joint Checking", institution: "Lakeside Credit Union", mask: "6610", account_type: "depository", subtype: "checking", balance: BigDecimal("1876.40")),
    Account.new(name: "High-Yield Savings", institution: "First Bank", mask: "1930", account_type: "depository", subtype: "savings", balance: BigDecimal("21905.00")),
    Account.new(name: "Emergency Fund", institution: "Lakeside Credit Union", mask: "2207", account_type: "depository", subtype: "savings", balance: BigDecimal("8500.00")),
    Account.new(name: "Roth IRA", institution: "Summit Investing", mask: "3318", account_type: "investment", subtype: "roth", balance: BigDecimal("31460.75")),
    Account.new(name: "Brokerage", institution: "Summit Investing", mask: "7702", account_type: "investment", subtype: "brokerage", balance: BigDecimal("22318.28")),
    Account.new(name: "Health Savings", institution: "Northside HSA", mask: "5521", account_type: "investment", subtype: "hsa", balance: BigDecimal("4120.55")),
    # Credit cards: balance is the amount owed.
    Account.new(name: "Rewards Credit Card", institution: "Harbor Card", mask: "0415", account_type: "credit", subtype: "credit card", balance: BigDecimal("2250.00")),
    Account.new(name: "Travel Credit Card", institution: "Harbor Card", mask: "9087", account_type: "credit", subtype: "credit card", balance: BigDecimal("812.40"))
  ].freeze

  HIGHLIGHTS = [
    Highlight.new(section: :transactions, stat: "$1,284.16", detail: "spent this month"),
    Highlight.new(section: :budgets, stat: "4 of 5", detail: "budgets on track"),
    Highlight.new(section: :subscriptions, stat: "$86.94/mo", detail: "across 6 subscriptions"),
    Highlight.new(section: :taxes, stat: "$4,210", detail: "estimated owed for 2026")
  ].freeze
end
