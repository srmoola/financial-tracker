require "rails_helper"

RSpec.describe Account, type: :model do
  fixtures :users

  let(:plaid_item) { users(:one).plaid_items.create!(item_id: "item-1", access_token: "access-sandbox-123") }

  it "stores Plaid's account type in account_type" do
    account = plaid_item.accounts.create!(plaid_account_id: "acc-1", name: "Credit Card", account_type: "credit", subtype: "credit card")

    expect(account.reload).to have_attributes(account_type: "credit", subtype: "credit card")
  end

  it "keeps balances to 4 decimal places" do
    account = plaid_item.accounts.create!(plaid_account_id: "acc-1", name: "Savings", account_type: "depository", current_balance: "1234.5678")

    expect(account.reload.current_balance).to eq(BigDecimal("1234.5678"))
  end

  it "requires a unique plaid_account_id, a name and an account type" do
    plaid_item.accounts.create!(plaid_account_id: "acc-1", name: "Checking", account_type: "depository")

    account = plaid_item.accounts.build(plaid_account_id: "acc-1")
    expect(account).not_to be_valid
    expect(account.errors.attribute_names).to include(:plaid_account_id, :name, :account_type)
  end
end
