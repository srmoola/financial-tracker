require "rails_helper"

RSpec.describe "Onboarding and the Accounts page", type: :request do
  include ActiveJob::TestHelper

  fixtures :users

  it "sends new sign-ups to the connect-accounts step once their email is confirmed, which they can skip" do
    perform_enqueued_jobs do
      post sign_up_path, params: { user: { first_name: "Ada", last_name: "Lovelace", email_address: "ada@example.com", password: "password123", password_confirmation: "password123" } }
    end
    post email_verification_path, params: { code: ActionMailer::Base.deliveries.last.subject[/\d{6}/] }
    expect(response).to redirect_to(onboarding_path)

    follow_redirect!
    expect(response.body).to include("Connect your accounts", "Bank or credit card", "Investment account", "Skip for now")
  end

  it "lists connected institutions and their accounts" do
    sign_in_as users(:one)
    item = users(:one).plaid_items.create!(item_id: "item-1", access_token: "token", institution_name: "First Platypus Bank", last_synced_at: 1.hour.ago)
    item.accounts.create!(plaid_account_id: "acc-1", name: "Plaid Credit Card", account_type: "credit", subtype: "credit card", mask: "3333", current_balance: 410)

    get accounts_path

    expect(response.body).to include("First Platypus Bank", "Plaid Credit Card", "Credit Card · •••• 3333", "−$410.00", "updated about 1 hour ago")
  end

  it "marks $0 accounts as not shown on the dashboard" do
    sign_in_as users(:one)
    item = users(:one).plaid_items.create!(item_id: "item-1", access_token: "token", institution_name: "First Platypus Bank")
    item.accounts.create!(plaid_account_id: "acc-1", name: "Plaid Checking", account_type: "depository", subtype: "checking", current_balance: 1200)
    item.accounts.create!(plaid_account_id: "acc-2", name: "Paid Off Card", account_type: "credit", subtype: "credit card", current_balance: 0)

    get accounts_path

    expect(response.body).to include("Plaid Checking", "Paid Off Card", "2 accounts")
    expect(response.body).not_to include("−$0.00")
    expect(response.body.scan("Not shown on dashboard").size).to eq(1)
  end

  it "shows an empty state with no connections" do
    sign_in_as users(:one)

    get accounts_path

    expect(response.body).to include("No accounts connected yet")
  end
end
