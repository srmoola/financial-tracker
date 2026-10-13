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
      expect(response.body).not_to include("Loan payments", "Weekly", "Monday to Sunday") # monthly only, for now

      expect {
        post budgets_path, params: { budget: { name: "Going out", amount: "200", categories: [ "", "FOOD_AND_DRINK", "ENTERTAINMENT" ], merchants: [ "", "Blue Bottle" ] } }
      }.to change(Budget, :count).by(1).and not_have_enqueued_mail

      expect(response).to redirect_to(budgets_path)
      expect(Budget.last).to have_attributes(name: "Going out", amount: 200, period: "monthly", categories: %w[ FOOD_AND_DRINK ENTERTAINMENT ], merchants: [ "Blue Bottle" ])

      follow_redirect!
      expect(response.body).to include("Going out", "$150.00", "of $200.00", "$50.00 left", "Food &amp; drink", "Entertainment", "Blue Bottle", "Monthly · ", "Resets ")
    end

    it "can roll over what's left, shown on the card" do
      travel_to Date.new(2026, 10, 14) do
        card.update!(last_statement_issue_date: Date.new(2026, 9, 15))

        get new_budget_path
        expect(response.body).to include("Roll over what's left")

        post budgets_path, params: { budget: { name: "Going out", amount: "200", rollover: "1", categories: [ "", "FOOD_AND_DRINK" ] } }
        budget = Budget.last
        expect(budget).to have_attributes(rollover: true, rollover_started_on: Date.new(2026, 10, 14))

        budget.update_column(:rollover_started_on, Date.new(2026, 9, 1)) # as if turned on last statement month
        get budgets_path
        expect(response.body).to include("Monthly · Rolls over", "of $400.00", "Includes $200.00 rolled over")
      end
    end

    it "shows what's missing" do
      post budgets_path, params: { budget: { name: "", amount: "", categories: [ "" ] } }

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

    it "shows how past periods went, on the card and on the budget's own page" do
      travel_to Date.new(2026, 10, 14) do
        card.update!(last_statement_issue_date: Date.new(2026, 9, 15))
        card.transactions.create!(plaid_transaction_id: "t1", amount: 250, date: Date.new(2026, 9, 10), category: "FOOD_AND_DRINK")
        card.transactions.create!(plaid_transaction_id: "t2", amount: 120, date: Date.new(2026, 7, 20), category: "FOOD_AND_DRINK")
        budget = users(:one).budgets.create!(name: "Going out", amount: 200, period: "monthly", categories: %w[ FOOD_AND_DRINK ])

        get budgets_path
        expect(response.body).to include("History", "Under budget in 0 of the last 1 month", budget_path(budget))

        get budget_path(budget)
        expect(response.body).to include("Aug 16 – Sep 15", "$250.00 of $200.00", "Over by $50.00")
        expect(response.body).to include("Jul 16 – Aug 15", "$120.00 of $200.00", "Under by $80.00", "partial: your data starts partway through") # data starts Jul 20
        expect(response.body).not_to include("Jun 16 – Jul 15")
      end
    end

    it "never shows or changes another user's budget" do
      theirs = users(:two).budgets.create!(name: "Theirs", amount: 100, categories: %w[ TRAVEL ])

      get budgets_path
      expect(response.body).not_to include("Theirs")
      get budget_path(theirs)
      expect(response).to have_http_status(:not_found)

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
