require "rails_helper"

RSpec.describe "Recategorizing transactions", type: :request do
  fixtures :users

  let(:card) do
    users(:one).plaid_items.create!(item_id: "item-1", access_token: "token")
      .accounts.create!(plaid_account_id: "card-1", name: "Card", account_type: "credit", subtype: "credit card")
  end
  let!(:amazon) { card.transactions.create!(plaid_transaction_id: "t-amazon", amount: 64.2, date: Date.current, merchant_name: "Amazon", category: "GENERAL_MERCHANDISE") }

  before { sign_in_as users(:one) }

  it "saves the user's category without touching Plaid's, and returns to the same view" do
    patch transaction_path(amazon), params: { category: "FOOD_AND_DRINK", return_to: "/transactions?range=3m&page=2" }

    expect(response).to redirect_to("/transactions?range=3m&page=2")
    expect(response).to have_http_status(:see_other)
    expect(amazon.reload).to have_attributes(category_override: "FOOD_AND_DRINK", category: "GENERAL_MERCHANDISE", effective_category: "FOOD_AND_DRINK")
  end

  it "counts the transaction under the new category in spending and filters" do
    card.transactions.create!(plaid_transaction_id: "t-coffee", amount: 5, date: Date.current, merchant_name: "Coffee", category: "FOOD_AND_DRINK")
    amazon.update!(category_override: "FOOD_AND_DRINK")

    get transactions_path(range: "1m", category: "FOOD_AND_DRINK")

    expect(response.body).to include("$69.20", "Amazon", "Coffee", "(changed by you)")
    expect(response.body).not_to include("Shopping</span>")
  end

  it "resets to Plaid's category with an empty choice or by picking Plaid's own category" do
    amazon.update!(category_override: "FOOD_AND_DRINK")
    patch transaction_path(amazon), params: { category: "" }
    expect(amazon.reload.category_override).to be_nil

    amazon.update!(category_override: "FOOD_AND_DRINK")
    patch transaction_path(amazon), params: { category: "GENERAL_MERCHANDISE" }
    expect(amazon.reload.category_override).to be_nil
  end

  it "rejects unknown categories" do
    patch transaction_path(amazon), params: { category: "NOT_A_CATEGORY" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(amazon.reload.category_override).to be_nil
  end

  it "only returns to pages within Transactions" do
    patch transaction_path(amazon), params: { category: "TRAVEL", return_to: "https://evil.example.com/transactions" }

    expect(response).to redirect_to(transactions_path)
  end

  it "can't change another user's transaction" do
    sign_out
    sign_in_as users(:two)

    patch transaction_path(amazon), params: { category: "TRAVEL" }

    expect(response).to have_http_status(:not_found)
    expect(amazon.reload.category_override).to be_nil
  end

  it "offers the category picker on each transaction" do
    get transactions_path(range: "1m")

    expect(response.body).to include("Change category", "recategorize#open", "Reset to Plaid's category")
    Transaction::CATEGORIES.each { |category| expect(response.body).to include(%(value="#{category}")) }
  end
end
