require "rails_helper"

RSpec.describe Subscription do
  fixtures :users

  let(:user) { users(:one) }
  let(:card) do
    user.plaid_items.create!(item_id: "item-1", access_token: "token")
      .accounts.create!(plaid_account_id: "card-1", name: "Quicksilver", account_type: "credit", subtype: "credit card", mask: "3333")
  end
  let(:today) { Date.new(2026, 10, 14) }

  def charge(amount, date, merchant: "Spotify", description: nil, category: "ENTERTAINMENT", arrived: date, account: card)
    account.transactions.create!(plaid_transaction_id: SecureRandom.hex(6), amount:, date:, merchant_name: merchant, description:, category:, created_at: arrived.in_time_zone.change(hour: 6))
  end

  def subscriptions(for_user: user) = Subscription.for(for_user, today:)

  it "finds a monthly subscription from three charges, with when it charges next" do
    [ Date.new(2026, 8, 10), Date.new(2026, 9, 10), Date.new(2026, 10, 10) ].each { |date| charge(6.99, date) }

    spotify = subscriptions.sole
    expect(spotify).to have_attributes(merchant: "Spotify", period: "monthly", status: :active, amount: 6.99, last_on: Date.new(2026, 10, 10), next_on: Date.new(2026, 11, 10), account: card, previous_amount: nil)
    expect([ spotify.monthly_cost, spotify.yearly_cost ]).to eq([ 6.99, 83.88 ])
  end

  it "shows the merchant's logo and website from the latest charge that has them" do
    [ Date.new(2026, 8, 10), Date.new(2026, 9, 10), Date.new(2026, 10, 10) ].each { |date| charge(6.99, date) }
    card.transactions.order(:date).first.update!(logo_url: "https://logos.example/old.png", website: "spotify.com")
    card.transactions.order(:date).second.update!(logo_url: "https://logos.example/spotify.png")

    expect(subscriptions.sole).to have_attributes(logo_url: "https://logos.example/spotify.png", website: "spotify.com")
  end

  it "suggests two charges of exactly the same amount a month apart, but not two different amounts" do
    charge(15.49, Date.new(2026, 9, 1), merchant: "Netflix")
    charge(15.49, Date.new(2026, 10, 1), merchant: "Netflix")
    charge(24.75, Date.new(2026, 9, 5), merchant: "Amazon")
    charge(25.05, Date.new(2026, 10, 5), merchant: "Amazon")

    expect(subscriptions.map { |subscription| [ subscription.merchant, subscription.status ] }).to eq([ [ "Netflix", :possible ] ])
  end

  it "keeps a subscription through a small price increase" do
    charge(14.99, Date.new(2026, 7, 20), merchant: "Netflix")
    charge(14.99, Date.new(2026, 8, 20), merchant: "Netflix")
    charge(15.49, Date.new(2026, 9, 20), merchant: "Netflix")

    expect(subscriptions.sole).to have_attributes(status: :active, amount: 15.49, previous_amount: 14.99)
  end

  it "follows a bigger price increase when the charge comes on schedule" do
    charge(13.99, Date.new(2026, 8, 1), merchant: "Disney+")
    charge(13.99, Date.new(2026, 9, 1), merchant: "Disney+")
    charge(15.99, Date.new(2026, 10, 1), merchant: "Disney+") # 14% more

    expect(subscriptions.sole).to have_attributes(status: :active, amount: 15.99, previous_amount: 13.99)
  end

  it "doesn't chain charges that change price every time, like a restaurant visited monthly" do
    { Date.new(2026, 8, 1) => 22.96, Date.new(2026, 9, 2) => 20.10, Date.new(2026, 10, 1) => 18.90 }.each { |date, amount| charge(amount, date, merchant: "Chipotle", category: "FOOD_AND_DRINK") }

    expect(subscriptions).to be_empty
  end

  it "ignores charges that aren't monthly or yearly, e.g. weekly or irregular" do
    [ 0, 7, 14, 21 ].each { |days| charge(2.99, Date.new(2026, 9, 1) + days, merchant: "Pizza", category: "FOOD_AND_DRINK") }
    [ Date.new(2026, 7, 1), Date.new(2026, 8, 1), Date.new(2026, 9, 25) ].each { |date| charge(28, date, merchant: "Planet Rock") }

    expect(subscriptions).to be_empty
  end

  it "finds yearly subscriptions" do
    charge(139, Date.new(2025, 9, 20), merchant: "Amazon Prime")
    charge(139, Date.new(2026, 9, 20), merchant: "Amazon Prime")

    expect(subscriptions.sole).to have_attributes(period: "yearly", status: :possible, next_on: Date.new(2027, 9, 20), yearly_cost: 139)
    expect(subscriptions.sole.monthly_cost).to be_within(0.01).of(11.58)
  end

  it "counts one as ended once its charge is more than 10 days overdue" do
    [ Date.new(2026, 6, 1), Date.new(2026, 7, 1), Date.new(2026, 8, 1) ].each { |date| charge(9.99, date, merchant: "Hulu") }

    expect(Subscription.for(user, today: Date.new(2026, 9, 11)).sole.status).to eq(:active)
    expect(Subscription.for(user, today: Date.new(2026, 9, 12)).sole.status).to eq(:ended)
  end

  it "tells apart two subscriptions at the same merchant by amount" do
    [ 8, 9, 10 ].each do |month|
      charge(2.99, Date.new(2026, month, 2), merchant: "Apple")
      charge(10.99, Date.new(2026, month, 15), merchant: "Apple")
    end

    expect(subscriptions.map { |subscription| [ subscription.merchant, subscription.amount ] }).to eq([ [ "Apple", 10.99 ], [ "Apple", 2.99 ] ])
  end

  it "groups statement descriptions without a merchant name, ignoring numbers, and skips masked ones" do
    charge(10, Date.new(2026, 8, 12), merchant: nil, description: "NETFLIX.COM 866-579-7172")
    charge(10, Date.new(2026, 9, 12), merchant: nil, description: "NETFLIX.COM 866-579-9999")
    charge(5, Date.new(2026, 8, 12), merchant: nil, description: "*********-********")
    charge(5, Date.new(2026, 9, 12), merchant: nil, description: "*********-********")

    expect(subscriptions.map(&:merchant)).to eq([ "NETFLIX.COM" ])
  end

  it "never counts refunds, card payments or another user's charges" do
    [ 7, 8, 9 ].each do |month|
      charge(-6.99, Date.new(2026, month, 10))
      charge(500, Date.new(2026, month, 20), merchant: "Capital One", category: "LOAN_PAYMENTS")
    end
    theirs = users(:two).plaid_items.create!(item_id: "item-2", access_token: "token-2")
      .accounts.create!(plaid_account_id: "card-2", name: "Theirs", account_type: "credit", subtype: "credit card")
    [ 8, 9, 10 ].each { |month| charge(6.99, Date.new(2026, month, 10), account: theirs) }

    expect(subscriptions).to be_empty
    expect(subscriptions(for_user: users(:two)).size).to eq(1)
  end

  describe "the user's choices" do
    before do
      charge(15.49, Date.new(2026, 9, 1), merchant: "Netflix")
      charge(15.49, Date.new(2026, 10, 1), merchant: "Netflix")
    end

    def mark(kind, **attributes) = user.subscription_marks.create!({ kind:, merchant: "Netflix", amount: 15.49, period: "monthly" }.merge(attributes))

    it "confirms a possible one" do
      mark("confirmed")

      expect(subscriptions.sole.status).to eq(:active)
    end

    it "hides one that isn't a subscription, even after its price changes a little" do
      mark("dismissed", amount: 15.00)

      expect(subscriptions).to be_empty
    end

    it "adds one by hand from a single charge, and doesn't double it once it's found" do
      charge(99, Date.new(2026, 3, 5), merchant: "iCloud")
      mark("added", merchant: "iCloud", amount: 99, period: "yearly", charged_on: Date.new(2026, 3, 5))
      mark("added", merchant: "Netflix", charged_on: Date.new(2026, 9, 1))

      expect(subscriptions.map { |subscription| [ subscription.merchant, subscription.period, subscription.status ] })
        .to contain_exactly([ "iCloud", "yearly", :active ], [ "Netflix", "monthly", :active ])
      expect(subscriptions.find { |subscription| subscription.merchant == "iCloud" }.next_on).to eq(Date.new(2027, 3, 5))
    end
  end

  it "is new for a week after the charge that made it a subscription came in" do
    charge(15.49, Date.new(2026, 9, 1), merchant: "Netflix")
    charge(15.49, Date.new(2026, 10, 1), merchant: "Netflix", arrived: Date.new(2026, 10, 9))

    netflix = subscriptions.sole
    expect(netflix.new?(now: Time.utc(2026, 10, 14))).to be(true)
    expect(netflix.new?(now: Time.utc(2026, 10, 17))).to be(false)
  end

  it "isn't new when the user added it themselves" do
    charge(15.49, Date.new(2026, 9, 1), merchant: "Netflix")
    charge(15.49, Date.new(2026, 10, 1), merchant: "Netflix", arrived: Date.new(2026, 10, 12))
    user.subscription_marks.create!(kind: "added", merchant: "Netflix", amount: 15.49, period: "monthly", charged_on: Date.new(2026, 10, 1))

    expect(subscriptions.sole.new?(now: Time.utc(2026, 10, 14))).to be(false)
  end

  it "lists the biggest monthly cost first" do
    charge(139, Date.new(2025, 10, 1), merchant: "Prime")
    charge(139, Date.new(2026, 10, 1), merchant: "Prime")
    charge(15.49, Date.new(2026, 9, 1), merchant: "Netflix")
    charge(15.49, Date.new(2026, 10, 1), merchant: "Netflix")

    expect(subscriptions.map(&:merchant)).to eq([ "Netflix", "Prime" ]) # $15.49 a month vs $11.58
  end
end
