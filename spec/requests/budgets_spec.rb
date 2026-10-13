require "rails_helper"

RSpec::Matchers.define_negated_matcher :not_have_enqueued_mail, :have_enqueued_mail

RSpec.describe "Budgets", type: :request do
  fixtures :users

  let(:card) do
    users(:one).plaid_items.create!(item_id: "item-1", access_token: "token")
      .accounts.create!(plaid_account_id: "card-1", name: "Card", account_type: "credit", subtype: "credit card")
  end

  it "requires login" do
    get budgets_path

    expect(response).to redirect_to(new_session_path)
  end

  context "when logged in" do
    before { sign_in_as users(:one) }

    it "invites you to create a first budget" do
      get budgets_path

      expect(response.body).to include("No budgets yet", "Create a budget", new_budget_path)
    end

    it "creates a budget with several categories and merchants, without emailing about spending already done" do
      card.transactions.create!(plaid_transaction_id: "t1", amount: 150, date: Date.current, category: "FOOD_AND_DRINK", merchant_name: "Blue Bottle")

      get new_budget_path
      expect(response.body).to include("Food &amp; drink", "Entertainment", "Search merchants", "Blue Bottle")
      expect(response.body).not_to include("Loan payments")

      expect {
        post budgets_path, params: { budget: { name: "Going out", amount: "200", period: "weekly", categories: [ "", "FOOD_AND_DRINK", "ENTERTAINMENT" ], merchants: [ "", "Blue Bottle" ] } }
      }.to change(Budget, :count).by(1).and not_have_enqueued_mail

      expect(response).to redirect_to(budgets_path)
      expect(Budget.last).to have_attributes(name: "Going out", amount: 200, period: "weekly", categories: %w[ FOOD_AND_DRINK ENTERTAINMENT ], merchants: [ "Blue Bottle" ])

      follow_redirect!
      expect(response.body).to include("Going out", "$150.00", "of $200.00", "$50.00 left", "Food &amp; drink", "Entertainment", "Blue Bottle", "Weekly · ", "Resets Mon, ")
    end

    it "shows what's missing" do
      post budgets_path, params: { budget: { name: "", amount: "", period: "monthly", categories: [ "" ] } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Name can&#39;t be blank", "Pick at least one category or merchant")
    end

    it "edits and deletes a budget" do
      budget = users(:one).budgets.create!(name: "Going out", amount: 200, period: "monthly", categories: %w[ FOOD_AND_DRINK ])

      patch budget_path(budget), params: { budget: { amount: "300", categories: [ "", "TRAVEL" ] } }
      expect(budget.reload).to have_attributes(amount: 300, categories: %w[ TRAVEL ])

      expect { delete budget_path(budget) }.to change(Budget, :count).by(-1)
      expect(response).to redirect_to(budgets_path)
    end

    it "never shows or changes another user's budget" do
      theirs = users(:two).budgets.create!(name: "Theirs", amount: 100, period: "weekly", categories: %w[ TRAVEL ])

      get budgets_path
      expect(response.body).not_to include("Theirs")

      get edit_budget_path(theirs)
      expect(response).to have_http_status(:not_found)
      delete budget_path(theirs)
      expect(response).to have_http_status(:not_found)
    end

    it "shows how many budgets are on track on the dashboard" do
      card.transactions.create!(plaid_transaction_id: "t1", amount: 500, date: Date.current, category: "TRAVEL")
      users(:one).budgets.create!(name: "Food", amount: 1000, period: "monthly", categories: %w[ FOOD_AND_DRINK ])
      users(:one).budgets.create!(name: "Trips", amount: 100, period: "monthly", categories: %w[ TRAVEL ])

      get root_path

      expect(response.body).to include("1 of 2", "budgets on track")
    end
  end
end
