require "rails_helper"

RSpec.describe AccountBalanceSnapshot, type: :model do
  fixtures :users

  let(:account) do
    users(:one).plaid_items.create!(item_id: "item-1", access_token: "access-sandbox-123")
      .accounts.create!(plaid_account_id: "acc-1", name: "Checking", account_type: "depository", subtype: "checking")
  end

  it "stores one balance per account per day" do
    account.balance_snapshots.create!(date: Date.current, balance: "1234.5678")

    duplicate = AccountBalanceSnapshot.new(account:, date: Date.current, balance: 1)
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:date]).to include("has already been taken")
    expect(account.balance_snapshots.sole.balance).to eq(BigDecimal("1234.5678"))
  end

  it "exposes the account's type and subtype for net worth grouping" do
    snapshot = account.balance_snapshots.create!(date: Date.current, balance: 10)

    expect(snapshot).to have_attributes(account_type: "depository", subtype: "checking")
  end

  it "is deleted with its account" do
    account.balance_snapshots.create!(date: Date.current, balance: 10)

    expect { account.destroy }.to change(AccountBalanceSnapshot, :count).by(-1)
  end
end
