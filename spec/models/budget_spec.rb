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
    expect(user.budgets.new(name: "Payments", amount: 10, period: "weekly", categories: %w[ LOAN_PAYMENTS ])).not_to be_valid
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

  it "counts weeks from Monday" do
    card
    spend(20, Date.new(2026, 10, 12)) # Monday
    spend(80, Date.new(2026, 10, 11)) # the Sunday before

    status = budget(period: "weekly").status

    expect(status).to have_attributes(spent: 20, starts_on: Date.new(2026, 10, 12), resets_on: Date.new(2026, 10, 19))
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
    going_out = budget(amount: 1000) # Oct 14 is day 29 of 30: 96.7% of the period passed
    expect(going_out.status.state).to eq(:on_track)

    spend(150, Date.new(2026, 10, 13))
    weekly = budget(period: "weekly", amount: 300) # Wednesday: 3 of 7 days, 42.9% passed; 50% spent
    expect(weekly.status.state).to eq(:on_track)
    spend(30, Date.new(2026, 10, 13)) # 60%: more than 10 points ahead
    expect(weekly.status.state).to eq(:over_pace)
    spend(150, Date.new(2026, 10, 13))
    expect(weekly.status.state).to eq(:over)
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
