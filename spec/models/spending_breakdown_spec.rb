require "rails_helper"

RSpec.describe SpendingBreakdown do
  fixtures :users

  let(:card) do
    users(:one).plaid_items.create!(item_id: "item-1", access_token: "token")
      .accounts.create!(plaid_account_id: "card-1", name: "Card", account_type: "credit", subtype: "credit card")
  end

  def spend(amount, category, id: SecureRandom.hex(4))
    card.transactions.create!(plaid_transaction_id: id, amount:, category:, date: Date.current)
  end

  it "totals purchases by category, ignoring payments and refunds" do
    spend(20, "FOOD_AND_DRINK")
    spend(5, "FOOD_AND_DRINK")
    spend(40, "TRAVEL")
    spend(-500, "LOAN_PAYMENTS")
    spend(-10, "FOOD_AND_DRINK")

    breakdown = SpendingBreakdown.new(card.transactions)

    expect(breakdown.categories.map { |category| [ category.label, category.total, category.count ] }).to eq([ [ "Travel", 40, 1 ], [ "Food & drink", 25, 2 ] ])
    expect(breakdown.total).to eq(65)
    expect(breakdown.purchase_count).to eq(3)
  end

  it "keeps the five largest categories and folds the rest into Other" do
    { "A" => 70, "B" => 60, "C" => 50, "D" => 40, "E" => 30, "F" => 20, nil => 10 }.each { |category, amount| spend(amount, category) }

    breakdown = SpendingBreakdown.new(card.transactions)

    expect(breakdown.categories.map(&:label)).to eq([ "A", "B", "C", "D", "E", "Other" ])
    expect(breakdown.categories.last).to have_attributes(key: :other, total: 30, count: 2)
    expect(breakdown.total).to eq(280)
  end

  it "labels Plaid categories readably" do
    expect(SpendingBreakdown.label_for("GENERAL_MERCHANDISE")).to eq("Shopping")
    expect(SpendingBreakdown.label_for("ENTERTAINMENT")).to eq("Entertainment")
    expect(SpendingBreakdown.label_for(nil)).to eq("Uncategorized")
  end
end
