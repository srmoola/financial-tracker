require "rails_helper"

RSpec.describe Budget do
  include ActiveJob::TestHelper
  fixtures :users

  let(:user) { users(:one) }
  let(:item) { user.plaid_items.create!(item_id: "item-1", access_token: "token") }
  let(:card) { item.accounts.create!(plaid_account_id: "card-1", name: "Card", account_type: "credit", subtype: "credit card", last_statement_issue_date: Date.new(2026, 9, 15)) }

  def spend(amount, date, category: "FOOD_AND_DRINK", merchant: "Coffee Shop", account: card)
    account.transactions.create!(plaid_transaction_id: SecureRandom.hex(6), amount:, date:, category:, merchant_name: merchant)
  end

  def budget(**attributes)
    user.budgets.create!({ name: "Going out", amount: 200, period: "monthly", categories: %w[ FOOD_AND_DRINK ENTERTAINMENT ] }.merge(attributes))
  end

  around { |example| travel_to(Date.new(2026, 10, 14)) { example.run } } # a Wednesday

  it "needs a name, a positive limit, a period, and at least one category or merchant" do
    invalid = user.budgets.new(name: " ", amount: 0, period: "daily")

    expect(invalid).not_to be_valid
    expect(invalid.errors.full_messages).to include("Name can't be blank", "Amount must be greater than 0", "Period is not included in the list", "Pick at least one category or merchant")
    expect(user.budgets.new(name: "Payments", amount: 10, categories: %w[ LOAN_PAYMENTS ])).not_to be_valid
    expect(user.budgets.new(name: "Coffee", amount: 10, period: "weekly", categories: %w[ FOOD_AND_DRINK ])).not_to be_valid # monthly only, for now
    expect(user.budgets.new.period).to eq("monthly")
  end

  it "counts this statement month's purchases in its categories, minus refunds" do
    card
    spend(30, Date.new(2026, 9, 16))
    spend(12, Date.new(2026, 10, 2), category: "ENTERTAINMENT")
    spend(-5, Date.new(2026, 10, 3), category: "ENTERTAINMENT") # a refund
    spend(99, Date.new(2026, 9, 15)) # the previous statement
    spend(50, Date.new(2026, 10, 4), category: "TRAVEL")

    status = budget.status

    expect(status).to have_attributes(spent: 37, starts_on: Date.new(2026, 9, 16), resets_on: Date.new(2026, 10, 16))
    expect(status.percent).to eq(18.5)
  end

  it "also counts picked merchants in any category, but never card payments or transfers" do
    card
    spend(25, Date.new(2026, 10, 1), category: "GENERAL_MERCHANDISE", merchant: "Amazon")
    spend(10, Date.new(2026, 10, 1), category: "GENERAL_MERCHANDISE", merchant: "Target")
    spend(300, Date.new(2026, 10, 2), category: "LOAN_PAYMENTS", merchant: "Amazon")
    card.transactions.create!(plaid_transaction_id: "no-merchant", amount: 7, date: Date.new(2026, 10, 2), category: "GENERAL_MERCHANDISE", description: "LOCAL SHOP")

    expect(budget(categories: [], merchants: [ "Amazon", "LOCAL SHOP" ]).status.spent).to eq(32)
    expect(budget(merchants: [ "Amazon" ]).status.spent).to eq(25)
  end

  it "uses the user's recategorized categories" do
    card
    spend(40, Date.new(2026, 10, 1), category: "TRAVEL").update!(category_override: "FOOD_AND_DRINK")

    expect(budget.status.spent).to eq(40)
  end

  it "is on track, over pace (spending faster than the period passes) or over" do
    card
    travel_to Date.new(2026, 9, 20) # day 5 of Sep 16 – Oct 15: 16.7% of the period passed
    going_out = budget

    spend(40, Date.new(2026, 9, 18)) # 20%
    expect(going_out.status.state).to eq(:on_track)
    spend(20, Date.new(2026, 9, 19)) # 30%: more than 10 points ahead
    expect(going_out.status.state).to eq(:over_pace)
    spend(150, Date.new(2026, 9, 19))
    expect(going_out.status.state).to eq(:over)
  end

  describe "history" do
    it "lists past statement months, newest first, back to the first transaction, marking partial ones" do
      card
      spend(250, Date.new(2026, 9, 10))  # Aug 16 – Sep 15: over
      spend(80, Date.new(2026, 8, 1))    # Jul 16 – Aug 15: under, but data starts Aug 1
      spend(30, Date.new(2026, 10, 1))   # this period: not history

      history = budget.history(6)

      expect(history.map { |status, partial| [ status.starts_on, status.resets_on, status.spent, status.over?, partial ] }).to eq([
        [ Date.new(2026, 8, 16), Date.new(2026, 9, 16), 250, true, false ],
        [ Date.new(2026, 7, 16), Date.new(2026, 8, 16), 80, false, true ]
      ])
    end

    it "is empty without transactions" do
      card

      expect(budget.history(6)).to eq([])
    end
  end

  describe "rollover" do
    # Statement months here: Jul 16 – Aug 15, Aug 16 – Sep 15, and this one, Sep 16 – Oct 15.
    def rollover_budget(**attributes)
      travel_to Date.new(2026, 8, 1) # turned on during Jul 16 – Aug 15
      budget(rollover: true, **attributes).tap { travel_to Date.new(2026, 10, 14) }
    end

    it "adds what's left of each period's limit to the next, from the period it was turned on in" do
      card
      going_out = rollover_budget
      spend(150, Date.new(2026, 7, 20)) # $50 left of $200
      spend(230, Date.new(2026, 8, 20)) # $20 left of $250
      spend(100, Date.new(2026, 6, 20)) # before rollover: doesn't carry

      expect(going_out.rollover_started_on).to eq(Date.new(2026, 8, 1))
      expect(going_out.status).to have_attributes(limit: 220, carried: 20)
      expect(going_out.history(3).map { |status, _| [ status.starts_on, status.limit, status.carried ] }).to eq([
        [ Date.new(2026, 8, 16), 250, 50 ],
        [ Date.new(2026, 7, 16), 200, 0 ],
        [ Date.new(2026, 6, 16), 200, 0 ]
      ])
    end

    it "doesn't take anything away for going over" do
      card
      going_out = rollover_budget
      spend(320, Date.new(2026, 7, 20)) # $120 over

      expect(going_out.status(back: 1)).to have_attributes(limit: 200, carried: 0)
      expect(going_out.status).to have_attributes(limit: 400, carried: 200) # nothing spent last period
    end

    it "uses the plain limit again once it's turned off, and counts afresh if turned back on" do
      card
      going_out = rollover_budget
      spend(50, Date.new(2026, 8, 20))

      going_out.update!(rollover: false)
      expect(going_out.rollover_started_on).to be_nil
      expect(going_out.status).to have_attributes(limit: 200, carried: 0)

      going_out.update!(rollover: true)
      expect(going_out.rollover_started_on).to eq(Date.new(2026, 10, 14))
      expect(going_out.status).to have_attributes(limit: 200, carried: 0)
      going_out.update!(name: "Fun") # other changes keep the start
      expect(going_out.rollover_started_on).to eq(Date.new(2026, 10, 14))
    end

    it "alerts against the rolled-over limit" do
      card
      going_out = rollover_budget
      spend(100, Date.new(2026, 7, 20)) # $100 left of $200
      spend(200, Date.new(2026, 8, 20)) # $100 left of $300
      spend(160, Date.new(2026, 10, 1)) # 53% of this period's $300 (it'd be 80% of $200)

      expect(going_out.status.limit).to eq(300)
      expect { going_out.send_alerts! }.to have_enqueued_mail(BudgetsMailer, :threshold).with(going_out, 50)
    end
  end

  describe "alerts" do
    it "emails the highest threshold reached, once per period" do
      card
      going_out = budget
      spend(110, Date.new(2026, 10, 1))

      expect { going_out.send_alerts! }.to have_enqueued_mail(BudgetsMailer, :threshold).with(going_out, 50)
      expect { going_out.send_alerts! }.not_to have_enqueued_mail

      spend(90, Date.new(2026, 10, 2)) # 100%, skipping past 90%
      expect { going_out.send_alerts! }.to have_enqueued_mail(BudgetsMailer, :threshold).with(going_out, 100)
      expect(going_out.alerts.pluck(:threshold)).to contain_exactly(50, 90, 100)
    end

    it "starts over in the next period" do
      card
      going_out = budget
      spend(150, Date.new(2026, 10, 1))
      going_out.send_alerts!

      travel_to Date.new(2026, 10, 20) # the next statement month, from Oct 16
      spend(120, Date.new(2026, 10, 18))
      expect { going_out.send_alerts! }.to have_enqueued_mail(BudgetsMailer, :threshold).with(going_out, 50)
    end

    it "doesn't email about thresholds already passed when a budget is set up or changed" do
      card
      spend(190, Date.new(2026, 10, 1))
      going_out = budget

      expect { going_out.reset_alerts! }.not_to have_enqueued_mail
      expect(going_out.alerts.pluck(:threshold)).to contain_exactly(50, 90)

      going_out.update!(amount: 500) # 38%: forget 50% and 90% so they can alert again
      going_out.reset_alerts!
      expect(going_out.alerts).to be_empty
    end

    it "never emails twice for the same threshold, even when checked twice at once" do
      card
      going_out = budget
      spend(150, Date.new(2026, 10, 1))
      going_out.alerts.create!(period_start: Date.new(2026, 9, 16), threshold: 50) # another check got there first

      expect { going_out.send_alerts! }.not_to have_enqueued_mail
    end
  end
end
