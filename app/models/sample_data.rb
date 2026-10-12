# Fake numbers for designing the dashboard before the Plaid integration exists.
# Delete this (and its uses in the views) once real accounts are synced.
module SampleData
  # Same shape as the Account model's columns (plus the institution from its PlaidItem).
  Account = Data.define(:name, :institution, :mask, :account_type, :subtype, :balance)
  Highlight = Data.define(:section, :stat, :detail)
  # Same shape as an AccountBalanceSnapshot row.
  Snapshot = Data.define(:account, :date, :balance) do
    delegate :account_type, :subtype, to: :account
  end

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

  # A year of daily balances per account, ending at each account's current balance.
  def self.snapshots(days: 365, today: Date.current)
    ACCOUNTS.flat_map do |account|
      (0...days).map do |days_ago|
        Snapshot.new(account:, date: today - days_ago, balance: historical_balance(account, days_ago))
      end
    end
  end

  # Made-up but plausible shapes, so the chart has something to show.
  def self.historical_balance(account, days_ago)
    wave = ->(period_in_days) { Math.sin(2 * Math::PI * days_ago / period_in_days) }
    balance = account.balance

    value =
      case [ account.account_type, account.subtype ]
      in [ "investment", _ ] then balance * (1 - 0.14 * days_ago / 365) * (1 + 0.03 * wave.(47)) # ~14% a year, with market swings
      in [ "credit", _ ] then balance * (1 + 0.35 * wave.(30)) # spent down and paid off each month
      in [ "depository", "checking" ] then balance * (1 + 0.2 * wave.(14)) # paychecks every two weeks
      in [ "depository", _ ] then balance - 350 * (days_ago / 30) # a deposit every month
      end
    value.round(2)
  end
end
