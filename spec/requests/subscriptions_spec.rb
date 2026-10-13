require "rails_helper"

RSpec.describe "Subscriptions", type: :request do
  fixtures :users

  let(:card) do
    users(:one).plaid_items.create!(item_id: "item-1", access_token: "token")
      .accounts.create!(plaid_account_id: "card-1", name: "Quicksilver", account_type: "credit", subtype: "credit card", mask: "3333")
  end

  def charge(amount, date, merchant:) = card.transactions.create!(plaid_transaction_id: SecureRandom.hex(6), amount:, date:, merchant_name: merchant, category: "ENTERTAINMENT")

  around { |example| travel_to(Date.new(2026, 10, 14)) { example.run } }

  it "requires login" do
    get subscriptions_path

    expect(response).to redirect_to(new_session_path)
  end

  context "when logged in" do
    before { sign_in_as users(:one) }

    it "explains what shows up when nothing's been found" do
      get subscriptions_path

      expect(response.body).to include("No subscriptions found yet", "Add a subscription")
    end

    it "lists subscriptions with their totals, possible ones to confirm, and ended ones" do
      [ 8, 9, 10 ].each { |month| charge(6.99, Date.new(2026, month, 10), merchant: "Spotify") }
      [ 9, 10 ].each { |month| charge(15.49, Date.new(2026, month, 1), merchant: "Netflix") }
      [ 5, 6, 7 ].each { |month| charge(9.99, Date.new(2026, month, 1), merchant: "Hulu") }

      get subscriptions_path

      expect(response.body).to include("$6.99", "a month", "$83.88", "a year · 1 subscription", "Spotify", "Monthly · Quicksilver •••• 3333", "Next Nov 10, 2026")
      expect(response.body).to include("Possible subscriptions", "Netflix", "Charged Sep 1 and Oct 1", "Yes, Netflix is a subscription")
      expect(response.body).to include("Ended (1)", "Hulu", "Last Jul 1")
    end

    it "confirms a possible subscription, or hides one that isn't" do
      [ 9, 10 ].each { |month| charge(15.49, Date.new(2026, month, 1), merchant: "Netflix") }
      [ 9, 10 ].each { |month| charge(40, Date.new(2026, month, 3), merchant: "Gym") }

      post confirm_subscriptions_path, params: { subscription: { merchant: "Netflix", amount: "15.49", period: "monthly" } }
      expect(response).to redirect_to(subscriptions_path)
      expect(flash[:notice]).to eq("Added Netflix to your subscriptions.")
      post dismiss_subscriptions_path, params: { subscription: { merchant: "Gym", amount: "40.0", period: "monthly" } }

      follow_redirect!
      expect(response.body).to include("Gym won&#39;t show up as a subscription.", "a year · 1 subscription", "Netflix")
      expect(response.body).not_to include("Possible subscriptions")

      post dismiss_subscriptions_path, params: { subscription: { merchant: "Netflix", amount: "15.49", period: "monthly" } } # replaces the confirmation
      expect(users(:one).subscription_marks.reload.pluck(:merchant, :kind)).to contain_exactly([ "Gym", "dismissed" ], [ "Netflix", "dismissed" ])
    end

    it "adds a subscription by hand from a recent charge" do
      icloud = charge(99, Date.new(2026, 9, 5), merchant: "iCloud")
      charge(99, Date.new(2026, 5, 5), merchant: "Too Old")

      get new_subscription_path
      expect(response.body).to include("iCloud", "Sep 5 · $99.00", "Add iCloud, $99.00 yearly")
      expect(response.body).not_to include("Too Old")

      post subscriptions_path, params: { transaction_id: icloud.id, period: "yearly" }
      expect(response).to redirect_to(subscriptions_path)
      follow_redirect!
      expect(response.body).to include("Added iCloud.", "iCloud", "Yearly", "Next Sep 5, 2027", "$99.00", "a year")
    end

    it "tags subscriptions, to tell apart ones from the same merchant" do
      [ 8, 9, 10 ].each { |month| charge(14.99, Date.new(2026, month, 2), merchant: "Amazon") }
      [ 8, 9, 10 ].each { |month| charge(9.99, Date.new(2026, month, 20), merchant: "Amazon") }
      prime = { merchant: "Amazon", amount: "14.99", period: "monthly" }

      post tags_subscriptions_path, params: { subscription: prime, tags: [ "  Prime  Video " ] }
      expect(response).to redirect_to(subscriptions_path(tagging: Subscription.for(users(:one)).find { |subscription| subscription.amount == 14.99 }.dom_id)) # to add another
      post tags_subscriptions_path, params: { subscription: { merchant: "Amazon", amount: "9.99", period: "monthly" }, tags: [ "Groceries" ] }
      post tags_subscriptions_path, params: { subscription: prime, tags: [ "Prime Video", "prime video", "Shared", "" ] } # repeats and blanks are dropped

      get subscriptions_path
      expect(response.body).to include("Prime Video", "Shared", "Groceries", "Remove tag Prime Video")
      expect(users(:one).subscription_marks.reload.pluck(:kind, :amount, :tags)).to contain_exactly([ "confirmed", 14.99, [ "Prime Video", "Shared" ] ], [ "confirmed", 9.99, [ "Groceries" ] ])

      post tags_subscriptions_path, params: { subscription: prime, tags: [ "Shared" ] } # removing one sends the rest
      expect(response).to redirect_to(subscriptions_path)
      post tags_subscriptions_path, params: { subscription: { merchant: "Amazon", amount: "9.99", period: "monthly" } } # the last one
      expect(users(:one).subscription_marks.reload.pluck(:tags)).to contain_exactly([ "Shared" ], [])

      post tags_subscriptions_path, params: { subscription: prime, tags: %w[ One Two Three Four ] }
      expect(response).to have_http_status(:unprocessable_content)
      post tags_subscriptions_path, params: { subscription: prime, tags: [ "x" * 21 ] }
      expect(response).to have_http_status(:unprocessable_content)
      post tags_subscriptions_path, params: { subscription: { merchant: "Hulu", amount: "9.99", period: "monthly" }, tags: [ "Nope" ] }
      expect(response).to have_http_status(:not_found)
    end

    it "keeps tags with an added subscription's own mark" do
      icloud = charge(99, Date.new(2026, 9, 5), merchant: "iCloud")
      post subscriptions_path, params: { transaction_id: icloud.id, period: "yearly" }

      post tags_subscriptions_path, params: { subscription: { merchant: "iCloud", amount: "99.0", period: "yearly" }, tags: [ "Family" ] }

      expect(users(:one).subscription_marks.reload.pluck(:kind, :tags)).to eq([ [ "added", [ "Family" ] ] ])
    end

    it "won't add another user's charge" do
      theirs = users(:two).plaid_items.create!(item_id: "item-2", access_token: "token-2")
        .accounts.create!(plaid_account_id: "card-2", name: "Theirs", account_type: "credit", subtype: "credit card")
        .transactions.create!(plaid_transaction_id: "theirs", amount: 10, date: Date.new(2026, 10, 1), merchant_name: "Theirs")

      post subscriptions_path, params: { transaction_id: theirs.id, period: "monthly" }

      expect(response).to have_http_status(:not_found)
    end

    it "shows the monthly total on the dashboard" do
      [ 8, 9, 10 ].each { |month| charge(6.99, Date.new(2026, month, 10), merchant: "Spotify") }

      get root_path

      expect(response.body).to include("$6.99/mo", "across 1 subscription")
    end
  end
end
