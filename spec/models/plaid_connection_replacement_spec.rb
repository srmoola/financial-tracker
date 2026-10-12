require "rails_helper"

RSpec.describe PlaidConnectionReplacement do
  fixtures :users

  let(:api) { stub_plaid_api }
  let(:old_item) { users(:one).plaid_items.create!(item_id: "old-item", access_token: "old-token", institution_name: "Capital One") }
  let(:new_item) { users(:one).plaid_items.create!(item_id: "new-item", access_token: "new-token", institution_name: "Capital One") }
  let(:old_card) { old_item.accounts.create!(plaid_account_id: "old-card", name: "Quicksilver", account_type: "credit", subtype: "credit card", mask: "7513", last_statement_issue_date: Date.new(2026, 9, 15)) }
  let(:new_card) { new_item.accounts.create!(plaid_account_id: "new-card", name: "Quicksilver", account_type: "credit", subtype: "credit card", mask: "7513") }

  before { allow(api).to receive(:item_remove) }

  it "moves balance history, category edits, notes and the statement date, then removes the old connection" do
    old_card.balance_snapshots.create!(date: Date.new(2026, 10, 1), balance: 100)
    old_card.balance_snapshots.create!(date: Date.new(2026, 10, 12), balance: 120)
    new_card.balance_snapshots.create!(date: Date.new(2026, 10, 12), balance: 125)
    old_card.transactions.create!(plaid_transaction_id: "old-t", amount: 64.2, date: Date.new(2026, 10, 5), merchant_name: "Amazon", description: "AMAZON RETA*", category: "GENERAL_MERCHANDISE", category_override: "FOOD_AND_DRINK")
    old_card.transactions.create!(plaid_transaction_id: "old-note", amount: 12, date: Date.new(2026, 10, 6), merchant_name: "Uber", description: "UBER", category: "TRANSPORTATION", note: "Airport ride")
    old_card.transactions.create!(plaid_transaction_id: "old-gone", amount: 5, date: Date.new(2026, 10, 7), merchant_name: "Gone", description: "GONE", note: "No match")
    new_transaction = new_card.transactions.create!(plaid_transaction_id: "new-t", amount: 64.2, date: Date.new(2026, 10, 5), merchant_name: "Amazon", description: "AMAZON RETA*", category: "GENERAL_MERCHANDISE")
    new_noted = new_card.transactions.create!(plaid_transaction_id: "new-note", amount: 12, date: Date.new(2026, 10, 6), merchant_name: "Uber", description: "UBER", category: "TRANSPORTATION")

    result = PlaidConnectionReplacement.new(old_item, new_item).run!

    expect(result).to have_attributes(accounts_matched: 1, snapshots_moved: 1, edits_copied: 2, edits_unmatched: 1, unmatched_accounts: [])
    expect(new_noted.reload.note).to eq("Airport ride")
    expect(new_card.balance_snapshots.order(:date).pluck(:date, :balance)).to eq([ [ Date.new(2026, 10, 1), 100 ], [ Date.new(2026, 10, 12), 125 ] ])
    expect(new_transaction.reload.category_override).to eq("FOOD_AND_DRINK")
    expect(new_card.reload.last_statement_issue_date).to eq(Date.new(2026, 9, 15))
    expect(api).to have_received(:item_remove).with(having_attributes(access_token: "old-token"))
    expect(PlaidItem.exists?(old_item.id)).to be(false)
  end

  it "still removes the old connection locally if Plaid already removed it" do
    old_card
    new_card
    allow(api).to receive(:item_remove).and_raise(plaid_api_error("ITEM_NOT_FOUND"))

    PlaidConnectionReplacement.new(old_item, new_item).run!

    expect(PlaidItem.exists?(old_item.id)).to be(false)
  end

  it "keeps the old connection if Plaid fails for another reason" do
    old_card
    new_card
    allow(api).to receive(:item_remove).and_raise(plaid_api_error("INTERNAL_SERVER_ERROR"))

    expect { PlaidConnectionReplacement.new(old_item, new_item).run! }.to raise_error(Plaid::ApiError)
    expect(PlaidItem.exists?(old_item.id)).to be(true)
  end

  it "reports accounts it couldn't match" do
    old_card
    old_item.accounts.create!(plaid_account_id: "old-checking", name: "360 Checking", account_type: "depository", subtype: "checking", mask: "1111")
    new_card

    expect(PlaidConnectionReplacement.new(old_item, new_item).run!.unmatched_accounts).to eq([ "360 Checking" ])
  end

  it "refuses to merge connections from different users" do
    other = users(:two).plaid_items.create!(item_id: "other", access_token: "t", institution_name: "Capital One")

    expect { PlaidConnectionReplacement.new(old_item, other) }.to raise_error(ArgumentError)
  end
end
