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

  describe "#display_name" do
    def named(merchant_name, description) = Transaction.new(merchant_name:, description:)

    it "uses Plaid's merchant name, then the statement description" do
      expect(named("Amazon", "AMAZON RETA* *********").display_name).to eq("Amazon")
      expect(named(nil, "DOUGLAS J* DOUGLAS J-A").display_name).to eq("DOUGLAS J* DOUGLAS J-A")
    end

    it "says Unknown merchant when the card masked the description, or there's no name at all" do
      expect(named(nil, "*********-********")).to have_attributes(display_name: "Unknown merchant", masked_description?: true)
      expect(named("", "********* RIDES").display_name).to eq("Unknown merchant")
      expect(named(nil, nil).display_name).to eq("Unknown merchant")
      expect(named("Amazon", "AMAZON ***************")).not_to be_masked_description
    end
  end

  describe "#split_into" do
    let(:costco) { account.transactions.create!(plaid_transaction_id: "costco", amount: 180, date: Date.current, category: "GENERAL_MERCHANDISE") }

    it "splits a purchase into parts that add up to it, and can undo it" do
      expect(costco.split_into([ { category: "FOOD_AND_DRINK", amount: "120.00" }, { category: "GENERAL_MERCHANDISE", amount: "60" } ])).to be(true)
      expect(costco.reload.splits.pluck(:category, :amount)).to eq([ [ "FOOD_AND_DRINK", 120 ], [ "GENERAL_MERCHANDISE", 60 ] ])
      expect(costco).to be_split

      costco.split_into([])
      expect(costco.reload).not_to be_split
    end

    it "rejects parts that don't add up, a single part, a missing category or amount, and non-purchases" do
      expect(costco.split_into([ { category: "FOOD_AND_DRINK", amount: "100" }, { category: "TRAVEL", amount: "60" } ])).to be(false)
      expect(costco.errors.full_messages).to include("The parts must add up to $180.00")
      expect(costco.split_into([ { category: "FOOD_AND_DRINK", amount: "180" } ])).to be(false)
      expect(costco.split_into([ { category: "", amount: "100" }, { category: "TRAVEL", amount: "80" } ])).to be(false)
      expect(costco.split_into([ { category: "TRAVEL", amount: "0" }, { category: "FOOD_AND_DRINK", amount: "180" } ])).to be(false)

      refund = account.transactions.create!(plaid_transaction_id: "refund", amount: -20, date: Date.current)
      expect(refund.split_into([ { category: "TRAVEL", amount: "10" }, { category: "FOOD_AND_DRINK", amount: "10" } ])).to be(false)
      expect(costco.reload.splits).to be_empty
    end
  end

  it "names who a transaction is with for grouping charges" do
    expect(Transaction.merchant_key("Spotify", "SPOTIFY P1234")).to eq("Spotify")
    expect(Transaction.merchant_key(nil, "NETFLIX.COM 866-579-7172")).to eq("NETFLIX.COM")
    expect(Transaction.merchant_key("", "*********-********")).to be_nil
  end
end
