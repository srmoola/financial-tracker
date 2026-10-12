require "rails_helper"

RSpec.describe PlaidItem, "disconnecting" do
  fixtures :users

  let(:api) { stub_plaid_api }
  let(:item) { users(:one).plaid_items.create!(item_id: "item-1", access_token: "access-1", institution_name: "Capital One") }
  let!(:card) { item.accounts.create!(plaid_account_id: "card-1", name: "Quicksilver", account_type: "credit", subtype: "credit card") }

  before do
    card.transactions.create!(plaid_transaction_id: "t1", amount: 10, date: Date.current)
    card.balance_snapshots.create!(date: Date.current, balance: 10)
  end

  it "removes the Item at Plaid, then deletes it with its accounts, transactions and balance history" do
    allow(api).to receive(:item_remove)

    item.disconnect!

    expect(api).to have_received(:item_remove).with(having_attributes(access_token: "access-1"))
    expect(PlaidItem.exists?(item.id)).to be(false)
    expect([ Account.count, Transaction.count, AccountBalanceSnapshot.count ]).to eq([ 0, 0, 0 ])
  end

  it "still deletes it locally if Plaid already removed it" do
    allow(api).to receive(:item_remove).and_raise(plaid_api_error("ITEM_NOT_FOUND"))

    item.disconnect!

    expect(PlaidItem.exists?(item.id)).to be(false)
  end

  it "keeps everything if Plaid fails for another reason" do
    allow(api).to receive(:item_remove).and_raise(plaid_api_error("INTERNAL_SERVER_ERROR"))

    expect { item.disconnect! }.to raise_error(Plaid::ApiError)
    expect([ PlaidItem.count, Account.count, Transaction.count ]).to eq([ 1, 1, 1 ])
  end
end
