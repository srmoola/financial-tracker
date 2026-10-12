require "rails_helper"

RSpec.describe "Daily sync history", type: :request do
  fixtures :users

  before { sign_in_as users(:one) }

  it "is linked from the Accounts page" do
    get accounts_path

    expect(response.body).to include("Daily sync history", sync_history_path)
  end

  it "says when there haven't been any daily syncs yet" do
    get sync_history_path

    expect(response.body).to include("No daily syncs yet")
  end

  it "shows whether the daily sync ran each day, and why a connection failed" do
    travel_to Time.utc(2026, 10, 12, 12) do
      bank = users(:one).plaid_items.create!(item_id: "item-1", access_token: "token-1", institution_name: "Capital One")
      bank.daily_syncs.create!(succeeded: true, created_at: Time.utc(2026, 10, 10, 6))
      bank.daily_syncs.create!(succeeded: false, error: "ITEM_LOGIN_REQUIRED", created_at: Time.utc(2026, 10, 12, 6, 0, 3))

      get sync_history_path

      expect(response.body).to include("Today", "Failed", "Capital One", "ITEM_LOGIN_REQUIRED", "1 of 1 connection · 6:00 AM UTC")
      expect(response.body).to include("Sun, Oct 11", "Didn&#39;t run", "Sat, Oct 10", "Synced")
    end
  end
end
