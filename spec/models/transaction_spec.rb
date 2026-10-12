require "rails_helper"

RSpec.describe Transaction, type: :model do
  fixtures :users

  let(:account) do
    users(:one).plaid_items.create!(item_id: "item-1", access_token: "access-sandbox-123")
      .accounts.create!(plaid_account_id: "acc-1", name: "Credit Card", account_type: "credit")
  end

  it "defaults to posted (not pending)" do
    transaction = account.transactions.create!(plaid_transaction_id: "txn-1", amount: 4.25, date: Date.current)

    expect(transaction.reload.pending).to be(false)
  end

  it "requires a unique plaid_transaction_id, an amount and a date" do
    account.transactions.create!(plaid_transaction_id: "txn-1", amount: 4.25, date: Date.current)

    transaction = account.transactions.build(plaid_transaction_id: "txn-1")
    expect(transaction).not_to be_valid
    expect(transaction.errors.attribute_names).to include(:plaid_transaction_id, :amount, :date)
  end
end
