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

      budget = Budget.last
      expect(response).to redirect_to(budget_path(budget))
      expect(budget).to have_attributes(name: "Going out", amount: 200, period: "monthly", categories: %w[ FOOD_AND_DRINK ENTERTAINMENT ], merchants: [ "Blue Bottle" ])

      follow_redirect! # the budget's own page
      expect(response.body).to include("Going out", "This month", "$150.00", "of $200.00", "$50.00 left", "Resets ")
      expect(response.body).to include("Monthly limit", "Your card's statement month", "Food &amp; drink", "Entertainment", "Blue Bottle", "Emails at 50%, 90% and 100%", edit_budget_path(budget))

      get budgets_path # a simple card that links to it
      expect(response.body).to include(budget_path(budget), "Going out", "of $200.00", "$50.00 left")
      expect(response.body).not_to include("History", "Blue Bottle")
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
        expect(response.body).to include("of $400.00", "includes $200.00 rolled over")

        get budget_path(budget)
        expect(response.body).to include("On, since Sep 1, 2026", "rolled over from the month before", "$200.00")
      end
    end

    it "shows what's missing" do
      post budgets_path, params: { budget: { name: "", amount: "", categories: [ "" ] } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Name can&#39;t be blank", "Pick at least one category or merchant")
    end

    it "edits and deletes a budget" do
      budget = users(:one).budgets.create!(name: "Going out", amount: 200, period: "monthly", categories: %w[ FOOD_AND_DRINK ])

      get edit_budget_path(budget)
      expect(response.body).to include("Delete budget", budget_path(budget)) # Cancel goes back to the budget

      patch budget_path(budget), params: { budget: { amount: "300", categories: [ "", "TRAVEL" ] } }
      expect(response).to redirect_to(budget_path(budget))
      expect(budget.reload).to have_attributes(amount: 300, categories: %w[ TRAVEL ])

      expect { delete budget_path(budget) }.to change(Budget, :count).by(-1)
      expect(response).to redirect_to(budgets_path)
    end

    it "lists how past months went on the budget's own page" do
      travel_to Date.new(2026, 10, 14) do
        card.update!(last_statement_issue_date: Date.new(2026, 9, 15))
        card.transactions.create!(plaid_transaction_id: "t1", amount: 250, date: Date.new(2026, 9, 10), category: "FOOD_AND_DRINK")
        card.transactions.create!(plaid_transaction_id: "t2", amount: 120, date: Date.new(2026, 7, 20), category: "FOOD_AND_DRINK")
        budget = users(:one).budgets.create!(name: "Going out", amount: 200, period: "monthly", categories: %w[ FOOD_AND_DRINK ])

        get budget_path(budget)
        expect(response.body).to include("History")
        expect(response.body).to include("Aug 16 – Sep 15", "$250.00 of $200.00", "Over by $50.00")
        expect(response.body).to include("Jul 16 – Aug 15", "$120.00 of $200.00", "Under by $80.00", "partial: your data starts partway through") # data starts Jul 20
        expect(response.body).not_to include("Jun 16 – Jul 15")
      end
    end

    describe "a budget's transactions" do
      let(:budget) { users(:one).budgets.create!(name: "Going out", amount: 200, categories: %w[ FOOD_AND_DRINK ]) }

      def add(id, amount, date, category: "FOOD_AND_DRINK", merchant: "Blue Bottle")
        card.transactions.create!(plaid_transaction_id: id, amount:, date:, category:, merchant_name: merchant)
      end

      around { |example| travel_to(Date.new(2026, 10, 14)) { example.run } }
      before { card.update!(last_statement_issue_date: Date.new(2026, 9, 15)) }

      it "lists this month's transactions that count, adding up to what's spent" do
        add("t1", 40, Date.new(2026, 10, 2), merchant: "Chipotle")
        add("t2", 25, Date.new(2026, 10, 5))
        add("t3", 99, Date.new(2026, 10, 5), category: "TRAVEL", merchant: "Delta")
        add("t4", 70, Date.new(2026, 9, 1), merchant: "Last Month")

        get budget_path(budget)

        expect(response.body).to include("2 transactions adding up to $65.00, biggest first", "Chipotle", "Food &amp; drink · Oct 2", "$40.00", "Blue Bottle", "Don&#39;t count Chipotle in Going out")
        expect(response.body).not_to include("Delta", "Last Month")
        expect(response.body.index("Chipotle")).to be < response.body.index("Blue Bottle") # biggest first
        expect(response.body).to include('data-turbo-confirm="Stop counting Chipotle ($40.00) in Going out? You can count it again later."')
      end

      it "takes a transaction out of the budget, and puts it back" do
        dinner = add("t1", 120, Date.new(2026, 10, 2), merchant: "Work Dinner")
        add("t2", 25, Date.new(2026, 10, 5))

        post budget_exclusions_path(budget), params: { transaction_id: dinner.id }
        expect(response).to redirect_to(budget_path(budget))
        expect(budget.status.spent).to eq(25)

        follow_redirect!
        expect(response.body).to include("1 transaction adding up to $25.00", "Not counted (1)", "Work Dinner", "Count again")

        delete budget_exclusion_path(budget, dinner)
        expect(budget.status.spent).to eq(145)
        expect(budget.exclusions).to be_empty
      end

      it "only takes it out of that budget" do
        dinner = add("t1", 120, Date.new(2026, 10, 2))
        everything = users(:one).budgets.create!(name: "Everything", amount: 1000, categories: %w[ FOOD_AND_DRINK TRAVEL ])

        post budget_exclusions_path(budget), params: { transaction_id: dinner.id }

        expect(budget.status.spent).to eq(0)
        expect(everything.status.spent).to eq(120)
      end

      it "shows a past month and its transactions from the history" do
        add("t1", 250, Date.new(2026, 9, 10), merchant: "Big Night Out")

        get budget_path(budget)
        expect(response.body).to include(budget_path(budget, back: 1))

        get budget_path(budget, back: 1)
        expect(response.body).to include('data-scroll-to="#period"', "You're looking at a past month: Aug 16 – Sep 15", "Past month", "Ended Sep 15, 2026", "Over budget", "$50.00 over", "Big Night Out", "Back to this month")

        get budget_path(budget)
        expect(response.body).not_to include("You're looking at a past month", "Past month")
      end

      it "shows the 5 biggest transactions, with the rest behind Show all" do
        7.times { |n| add("t#{n}", 10 + n, Date.new(2026, 10, 2), merchant: "Place #{n}") }
        card.transactions.find_by!(plaid_transaction_id: "t6").update!(logo_url: "https://logos.example/place.png")

        get budget_path(budget)

        shown, more = response.body.split('id="more-budget-transactions"')
        expect(shown).to include("Place 6", "Place 2", 'src="https://logos.example/place.png"')
        expect(shown).not_to include("Place 1", "Place 0")
        expect(more).to include("Place 1", "Place 0", "Show less")
      end

      it "doesn't offer Show all for 5 or fewer" do
        5.times { |n| add("t#{n}", 10 + n, Date.new(2026, 10, 2)) }

        get budget_path(budget)

        expect(response.body).not_to include("Show all")
      end

      it "won't take another user's transaction" do
        theirs = users(:two).plaid_items.create!(item_id: "item-2", access_token: "token-2")
          .accounts.create!(plaid_account_id: "card-2", name: "Their Card", account_type: "credit", subtype: "credit card")
          .transactions.create!(plaid_transaction_id: "theirs", amount: 5, date: Date.new(2026, 10, 2), category: "FOOD_AND_DRINK")

        post budget_exclusions_path(budget), params: { transaction_id: theirs.id }

        expect(response).to have_http_status(:not_found)
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
      post budget_exclusions_path(theirs), params: { transaction_id: "anything" }
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
