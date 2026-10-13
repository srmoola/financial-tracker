require "rails_helper"

RSpec.describe "Splitting a transaction", type: :request do
  fixtures :users

  let(:card) do
    users(:one).plaid_items.create!(item_id: "item-1", access_token: "token")
      .accounts.create!(plaid_account_id: "card-1", name: "Rewards Card", account_type: "credit", subtype: "credit card")
  end
  let!(:costco) { card.transactions.create!(plaid_transaction_id: "costco", amount: 180, date: Date.current, category: "GENERAL_MERCHANDISE", merchant_name: "Costco") }

  before { sign_in_as users(:one) }

  def split(parts, return_to: "/transactions?list_range=1m")
    patch transaction_split_path(costco), params: { parts:, return_to: }
  end

  it "offers splitting from the category picker" do
    get transactions_path

    expect(response.body).to include("Split across categories", "data-recategorize-split-url-param=\"#{transaction_split_path(costco)}\"", "data-recategorize-total-param=\"180.0\"")
  end

  it "splits a purchase, shows the parts everywhere, and goes back to the same page" do
    split([ { category: "FOOD_AND_DRINK", amount: "120" }, { category: "GENERAL_MERCHANDISE", amount: "60" } ])

    expect(response).to redirect_to("/transactions?list_range=1m")
    get transactions_path
    expect(response.body).to include("Split · Food &amp; drink, Shopping", "Split into Food &amp; drink $120.00 and Shopping $60.00. Change split")
    expect(response.body).to include("$120.00", "$60.00") # the donut's Food & drink and Shopping
  end

  it "rejects parts that don't add up" do
    split([ { category: "FOOD_AND_DRINK", amount: "100" }, { category: "GENERAL_MERCHANDISE", amount: "60" } ])

    expect(response).to have_http_status(:unprocessable_content)
    expect(costco.reload.splits).to be_empty
  end

  it "removes a split" do
    costco.split_into([ { category: "FOOD_AND_DRINK", amount: 120 }, { category: "GENERAL_MERCHANDISE", amount: 60 } ])

    delete transaction_split_path(costco), params: { return_to: "/transactions" }

    expect(response).to redirect_to("/transactions")
    expect(costco.reload.splits).to be_empty
  end

  it "won't split another user's transaction" do
    theirs = users(:two).plaid_items.create!(item_id: "item-2", access_token: "token-2")
      .accounts.create!(plaid_account_id: "card-2", name: "Their Card", account_type: "credit", subtype: "credit card")
      .transactions.create!(plaid_transaction_id: "theirs", amount: 50, date: Date.current)

    patch transaction_split_path(theirs), params: { parts: [ { category: "TRAVEL", amount: "25" }, { category: "TRAVEL", amount: "25" } ] }

    expect(response).to have_http_status(:not_found)
  end
end
