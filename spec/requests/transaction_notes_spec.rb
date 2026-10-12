require "rails_helper"

RSpec.describe "Transaction notes", type: :request do
  fixtures :users

  let(:card) do
    users(:one).plaid_items.create!(item_id: "item-1", access_token: "token")
      .accounts.create!(plaid_account_id: "card-1", name: "Card", account_type: "credit", subtype: "credit card")
  end
  let!(:amazon) { card.transactions.create!(plaid_transaction_id: "t-amazon", amount: 64.2, date: Date.current, merchant_name: "Amazon", category: "GENERAL_MERCHANDISE") }

  before { sign_in_as users(:one) }

  it "saves a note (trimmed) and shows it under the transaction" do
    patch transaction_path(amazon), params: { note: "  Groceries for the week  ", return_to: "/transactions?range=1m" }

    expect(response).to redirect_to("/transactions?range=1m")
    expect(amazon.reload.note).to eq("Groceries for the week")

    get transactions_path(range: "1m")
    expect(response.body).to include("Note: </span>Groceries for the week", "Edit note for Amazon")
  end

  it "removes the note when it's saved blank" do
    amazon.update!(note: "Old note")

    patch transaction_path(amazon), params: { note: "   " }

    expect(amazon.reload.note).to be_nil
  end

  it "leaves the category alone when only the note changes, and vice versa" do
    amazon.update!(category_override: "FOOD_AND_DRINK", note: "Keep me")

    patch transaction_path(amazon), params: { note: "New note" }
    expect(amazon.reload).to have_attributes(category_override: "FOOD_AND_DRINK", note: "New note")

    patch transaction_path(amazon), params: { category: "TRAVEL" }
    expect(amazon.reload).to have_attributes(category_override: "TRAVEL", note: "New note")
  end

  it "rejects notes longer than 280 characters" do
    patch transaction_path(amazon), params: { note: "x" * 281 }

    expect(response).to have_http_status(:unprocessable_content)
    expect(amazon.reload.note).to be_nil
  end

  it "can't add a note to another user's transaction" do
    sign_out
    sign_in_as users(:two)

    patch transaction_path(amazon), params: { note: "Not mine" }

    expect(response).to have_http_status(:not_found)
    expect(amazon.reload.note).to be_nil
  end

  it "offers an 'Add a note' button and the note editor" do
    get transactions_path(range: "1m")

    expect(response.body).to include("Add a note for Amazon", "Save note", 'maxlength="280"')
  end
end
