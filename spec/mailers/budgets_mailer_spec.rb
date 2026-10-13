require "rails_helper"

RSpec.describe BudgetsMailer do
  fixtures :users

  let(:card) do
    users(:one).plaid_items.create!(item_id: "item-1", access_token: "token")
      .accounts.create!(plaid_account_id: "card-1", name: "Card", account_type: "credit", subtype: "credit card", last_statement_issue_date: Date.new(2026, 9, 15))
  end
  let(:budget) { users(:one).budgets.create!(name: "Going out", amount: 200, categories: %w[ FOOD_AND_DRINK ], merchants: %w[ Amazon ]) }

  around { |example| travel_to(Date.new(2026, 10, 14)) { example.run } }

  it "says how much of the budget is used and what's left" do
    card.transactions.create!(plaid_transaction_id: "t1", amount: 180, date: Date.new(2026, 10, 13), category: "FOOD_AND_DRINK")

    mail = BudgetsMailer.threshold(budget, 90)

    expect(mail.to).to eq([ "one@example.com" ])
    expect(mail.subject).to eq("You've used 90% of your Going out budget")
    expect(mail.text_part.body.to_s).to include("You've used 90% of your Going out budget this statement month: $180.00 of $200.00, with $20.00 left.", "It counts Food & drink and Amazon.", "Resets Fri, Oct 16", "/budgets")
  end

  it "says when the budget is reached, and by how much it's over" do
    card.transactions.create!(plaid_transaction_id: "t1", amount: 230, date: Date.new(2026, 10, 13), category: "FOOD_AND_DRINK")

    mail = BudgetsMailer.threshold(budget, 100)

    expect(mail.subject).to eq("You've reached your Going out budget")
    expect(mail.text_part.body.to_s).to include("$230.00 of $200.00 ($30.00 over)")
  end
end
