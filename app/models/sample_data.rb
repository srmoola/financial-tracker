# Fake numbers for designing the dashboard before the Plaid integration exists.
# Delete this (and its uses in the views) once real accounts are synced.
module SampleData
  Account = Data.define(:name, :institution, :mask, :balance)
  Highlight = Data.define(:section, :stat, :detail)

  # Asset accounts, largest first. Their order sets the donut's slice order and colors.
  ASSETS = [
    Account.new(name: "Roth IRA", institution: "Summit Investing", mask: "3318", balance: BigDecimal("31460.75")),
    Account.new(name: "Brokerage", institution: "Summit Investing", mask: "7702", balance: BigDecimal("22318.28")),
    Account.new(name: "High-Yield Savings", institution: "First Bank", mask: "1930", balance: BigDecimal("21905.00")),
    Account.new(name: "Everyday Checking", institution: "First Bank", mask: "4821", balance: BigDecimal("6240.12")),
    Account.new(name: "Health Savings", institution: "Northside HSA", mask: "5521", balance: BigDecimal("4120.55"))
  ].freeze

  # Credit card balances owed.
  DEBTS = [
    Account.new(name: "Rewards Credit Card", institution: "Harbor Card", mask: "0415", balance: BigDecimal("2250.00")),
    Account.new(name: "Travel Credit Card", institution: "Harbor Card", mask: "9087", balance: BigDecimal("812.40"))
  ].freeze

  HIGHLIGHTS = [
    Highlight.new(section: :transactions, stat: "$1,284.16", detail: "spent this month"),
    Highlight.new(section: :budgets, stat: "4 of 5", detail: "budgets on track"),
    Highlight.new(section: :subscriptions, stat: "$86.94/mo", detail: "across 6 subscriptions"),
    Highlight.new(section: :taxes, stat: "$4,210", detail: "estimated owed for 2026")
  ].freeze

  def self.assets_total = ASSETS.sum(&:balance)
  def self.debts_total = DEBTS.sum(&:balance)
  def self.net_worth = assets_total - debts_total
end
