require "rails_helper"

RSpec.describe NetWorthHistory do
  def snapshot(account_type, subtype, date, balance)
    account = SampleData::Account.new(name: "Account", institution: "Bank", mask: "0000", account_type:, subtype:, balance: 0)
    SampleData::Snapshot.new(account:, date:, balance: BigDecimal(balance))
  end

  let(:today) { Date.new(2026, 10, 12) }

  it "adds up each day's account snapshots into net worth, oldest first" do
    history = NetWorthHistory.new([
      snapshot("depository", "checking", today, "100"),
      snapshot("credit", "credit card", today, "30"),
      snapshot("depository", "checking", today - 1, "80"),
      snapshot("investment", "brokerage", today - 1, "20")
    ])

    expect(history.points.map { |point| [ point.date, point.net_worth ] }).to eq([ [ today - 1, 100 ], [ today, 70 ] ])
    expect(history.change).to eq(-30)
    expect(history.change_percent).to eq(-30)
  end

  it "starts each range the right number of months back" do
    expect(NetWorthHistory.range_start("1m", today:)).to eq(Date.new(2026, 9, 12))
    expect(NetWorthHistory.range_start("1y", today:)).to eq(Date.new(2025, 10, 12))
  end
end
