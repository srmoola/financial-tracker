require "rails_helper"

RSpec.describe WeeklyDigestMailer do
  fixtures :users

  around { |example| travel_to(Time.utc(2026, 10, 19, 13)) { example.run } }

  it "summarizes last week, with a link (and mail-client button) to turn it off" do
    item = users(:one).plaid_items.create!(item_id: "item-1", access_token: "token", institution_name: "Capital One")
    card = item.accounts.create!(plaid_account_id: "card-1", name: "Card", account_type: "credit", subtype: "credit card", last_statement_issue_date: Date.new(2026, 9, 15))
    card.transactions.create!(plaid_transaction_id: "t1", amount: 82.5, date: Date.new(2026, 10, 14), category: "FOOD_AND_DRINK", merchant_name: "Whole Foods", created_at: Time.utc(2026, 10, 15))
    users(:one).budgets.create!(name: "Going out", amount: 200, categories: %w[ FOOD_AND_DRINK ])
    item.daily_syncs.create!(succeeded: false, error: "ITEM_LOGIN_REQUIRED", created_at: Time.utc(2026, 10, 15, 6))

    mail = WeeklyDigestMailer.summary(users(:one))
    text = mail.text_part.body.to_s

    expect(mail.subject).to eq("Your week: $82.50 in new spending")
    expect(text).to include("here's your week (Oct 12 – Oct 18)", "$82.50 across 1 purchase, with none the week before", "Food & drink: $82.50", "Whole Foods (Oct 14): $82.50")
    expect(text).to include("Going out: $0.00 of $200.00 (On track)", "Capital One didn't sync (ITEM_LOGIN_REQUIRED)") # a new statement month started Oct 16
    expect(mail.header["List-Unsubscribe-Post"].value).to eq("List-Unsubscribe=One-Click")
    token = mail.header["List-Unsubscribe"].value[/token=([^>&]+)/, 1]
    expect(User.find_by_token_for(:weekly_digest, CGI.unescape(token))).to eq(users(:one))
    expect(text).to include("Turn it off: http://")
  end
end
