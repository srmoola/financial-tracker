require "rails_helper"

RSpec.describe "Transactions page", type: :request do
  fixtures :users

  let(:item) { users(:one).plaid_items.create!(item_id: "item-1", access_token: "token", institution_name: "First Platypus Bank") }
  let(:card) { item.accounts.create!(plaid_account_id: "card-1", name: "Rewards Card", account_type: "credit", subtype: "credit card", mask: "3333") }

  def add_transaction(amount:, date: Date.current, merchant: "Coffee Shop", category: "FOOD_AND_DRINK", account: card, pending: false)
    account.transactions.create!(plaid_transaction_id: SecureRandom.hex(6), amount:, date:, merchant_name: merchant, category:, pending:)
  end

  before { sign_in_as users(:one) }

  it "asks to connect a credit card when there are none" do
    get transactions_path

    expect(response.body).to include("Connect a credit card", "Bank or credit card")
  end

  it "says transactions are on the way before the first sync" do
    card

    get transactions_path

    expect(response.body).to include("Your transactions are on the way")
  end

  it "shows spending by category and the list of transactions for the last month by default" do
    add_transaction(amount: 12.5, merchant: "Coffee Shop")
    add_transaction(amount: 80, merchant: "Airline", category: "TRAVEL", pending: true)
    add_transaction(amount: -200, merchant: nil, category: "LOAN_PAYMENTS")
    add_transaction(amount: 999, merchant: "Old Purchase", date: 2.months.ago.to_date)

    get transactions_path

    expect(response.body).to include("Spending", "$92.50", "2 purchases", "Food &amp; drink", "Travel")
    expect(response.body).to include("Coffee Shop", "Airline", "Pending", "+$200.00", "Rewards Card •••• 3333", "3 transactions in the last month")
    expect(response.body).not_to include("Old Purchase")
  end

  it "includes older transactions for a longer range" do
    add_transaction(amount: 999, merchant: "Old Purchase", date: 2.months.ago.to_date)

    get transactions_path(range: "3m")

    expect(response.body).to include("Old Purchase", "$999.00")
  end

  it "paginates 25 transactions per page, newest first" do
    30.times { |days_ago| add_transaction(amount: 1, merchant: "Shop #{days_ago}", date: Date.current - days_ago) }

    get transactions_path(range: "3m")
    expect(response.body).to include("Page 1 of 2", "Shop 0", "Shop 24")
    expect(response.body).not_to include("Shop 25")

    get transactions_path(range: "3m", page: 2)
    expect(response.body).to include("Page 2 of 2", "Shop 25", "Shop 29")
    expect(response.body).not_to include("Shop 24<")

    get transactions_path(range: "3m", page: 99)
    expect(response.body).to include("Page 2 of 2")
  end

  it "never shows another user's transactions" do
    add_transaction(amount: 10, merchant: "Mine")
    other_card = users(:two).plaid_items.create!(item_id: "item-2", access_token: "token-2")
      .accounts.create!(plaid_account_id: "card-2", name: "Their Card", account_type: "credit", subtype: "credit card")
    add_transaction(amount: 77, merchant: "Theirs", account: other_card)

    get transactions_path

    expect(response.body).to include("Mine")
    expect(response.body).not_to include("Theirs", "$77.00")
  end

  it "shows last month's spending on the dashboard card" do
    add_transaction(amount: 42)

    get root_path

    expect(response.body).to include("$42.00", "spent on credit cards in the last month")
  end
end
