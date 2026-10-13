require "rails_helper"

RSpec.describe WeeklyDigest do
  fixtures :users

  let(:user) { users(:one) }
  let(:item) { user.plaid_items.create!(item_id: "item-1", access_token: "token", institution_name: "Capital One") }
  let(:card) { item.accounts.create!(plaid_account_id: "card-1", name: "Card", account_type: "credit", subtype: "credit card", last_statement_issue_date: Date.new(2026, 9, 15)) }
  let(:digest) { WeeklyDigest.new(user) }

  # Monday Oct 19: the email covers Oct 12 – 18.
  around { |example| travel_to(Time.utc(2026, 10, 19, 13)) { example.run } }

  def arrived(amount, on:, bought: on, category: "FOOD_AND_DRINK", merchant: "Shop")
    card.transactions.create!(plaid_transaction_id: SecureRandom.hex(6), amount:, date: bought, category:, merchant_name: merchant, created_at: on.in_time_zone.change(hour: 6))
  end

  it "covers Monday to Sunday of last week" do
    expect(digest).to have_attributes(starts_on: Date.new(2026, 10, 12), ends_on: Date.new(2026, 10, 18))
  end

  it "counts the purchases that came in last week, compared with the week before" do
    arrived(40, on: Date.new(2026, 10, 13), bought: Date.new(2026, 10, 9), merchant: "Bought Before, Arrived Last Week")
    arrived(60, on: Date.new(2026, 10, 18), category: "TRAVEL", merchant: "Delta")
    arrived(-15, on: Date.new(2026, 10, 14)) # a refund isn't new spending
    arrived(30, on: Date.new(2026, 10, 7)) # the week before
    arrived(999, on: Date.new(2026, 10, 13), bought: Date.new(2026, 7, 1)) # history from a new connection
    arrived(25, on: Date.new(2026, 10, 19)) # this week

    expect(digest).to have_attributes(spent: 100, purchase_count: 2, spent_the_week_before: 30)
    expect(digest.biggest_purchases.map(&:display_name)).to eq([ "Delta", "Bought Before, Arrived Last Week" ])
    expect(digest.top_categories.map { |category| [ category.label, category.total ] }).to eq([ [ "Travel", 60 ], [ "Food & drink", 40 ] ])
  end

  it "counts a split purchase's parts in its top categories" do
    costco = arrived(180, on: Date.new(2026, 10, 14), category: "GENERAL_MERCHANDISE")
    costco.split_into([ { category: "FOOD_AND_DRINK", amount: 120 }, { category: "GENERAL_MERCHANDISE", amount: 60 } ])

    expect(digest.top_categories.map(&:label)).to eq([ "Food & drink", "Shopping" ])
  end

  it "has each budget's month so far, net worth's change, and connections that failed to sync" do
    budget = user.budgets.create!(name: "Going out", amount: 200, categories: %w[ FOOD_AND_DRINK ])
    checking = item.accounts.create!(plaid_account_id: "chk-1", name: "Checking", account_type: "depository", subtype: "checking")
    checking.balance_snapshots.create!(date: Date.new(2026, 10, 11), balance: 1000)
    checking.balance_snapshots.create!(date: Date.new(2026, 10, 18), balance: 1250)
    item.daily_syncs.create!(succeeded: false, error: "ITEM_LOGIN_REQUIRED", created_at: Time.utc(2026, 10, 15, 6))
    item.daily_syncs.create!(succeeded: false, error: "OLD_ERROR", created_at: Time.utc(2026, 10, 8, 6))

    expect(digest.budgets.map { |b, status| [ b, status.limit ] }).to eq([ [ budget, 200 ] ])
    expect(digest.net_worth_change).to eq([ 250, 1250 ])
    expect(digest.sync_failures).to eq([ [ item, "ITEM_LOGIN_REQUIRED" ] ])
  end

  it "has no net worth change without balances for both days, and isn't sent without accounts" do
    expect(digest.net_worth_change).to be_nil
    expect(WeeklyDigest.new(users(:two))).not_to be_worth_sending
  end

  it "has the subscriptions found last week" do
    arrived(15.49, on: Date.new(2026, 9, 1), merchant: "Netflix", category: "ENTERTAINMENT")
    arrived(15.49, on: Date.new(2026, 10, 1), bought: Date.new(2026, 10, 1), merchant: "Netflix", category: "ENTERTAINMENT").update!(created_at: Time.utc(2026, 10, 13, 6))
    [ 7, 8, 9 ].each { |month| arrived(6.99, on: Date.new(2026, month, 10), merchant: "Spotify", category: "ENTERTAINMENT") } # found long ago

    expect(digest.new_subscriptions.map { |subscription| [ subscription.merchant, subscription.status ] }).to eq([ [ "Netflix", :possible ] ])
  end
end
