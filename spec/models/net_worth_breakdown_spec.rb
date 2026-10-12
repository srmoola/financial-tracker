require "rails_helper"

RSpec.describe NetWorthBreakdown do
  def account(account_type, subtype, balance)
    SampleData::Account.new(name: "#{subtype} account", institution: "Bank", mask: "0000", account_type:, subtype:, balance: BigDecimal(balance))
  end

  it "groups accounts into checking, savings and investments, with credit cards as debts" do
    breakdown = NetWorthBreakdown.new([
      account("depository", "checking", "100"),
      account("depository", "checking", "50"),
      account("depository", "savings", "1000"),
      account("investment", "roth", "500"),
      account("credit", "credit card", "75")
    ])

    expect(breakdown.groups.map { |group| [ group.label, group.accounts.size, group.total ] }).to eq([
      [ "Checking", 2, 150 ], [ "Savings", 1, 1000 ], [ "Investments", 1, 500 ]
    ])
    expect(breakdown.debts.size).to eq(1)
    expect(breakdown.assets_total).to eq(1650)
    expect(breakdown.debts_total).to eq(75)
    expect(breakdown.net_worth).to eq(1575)
    expect(breakdown.asset_account_count).to eq(4)
  end

  it "leaves out categories with no accounts" do
    breakdown = NetWorthBreakdown.new([ account("investment", "brokerage", "10") ])

    expect(breakdown.groups.map(&:key)).to eq([ :investments ])
  end

  it "refuses account types it doesn't handle yet instead of dropping them from net worth" do
    expect { NetWorthBreakdown.new([ account("loan", "student", "10") ]) }.to raise_error(NoMatchingPatternError)
  end
end
