require "rails_helper"

RSpec.describe "Pages", type: :request do
  fixtures :users

  it "shows the landing page when logged out" do
    get root_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("See all your money in")
    expect(response.body).not_to include("Log out")
  end

  it "shows the dashboard when logged in" do
    sign_in_as users(:one)

    get root_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Jane Doe", "JD", "Log out")
    expect(response.body).not_to include("See all your money in")
  end

  it "uses real accounts and snapshots once accounts are connected" do
    sign_in_as users(:one)
    item = users(:one).plaid_items.create!(item_id: "item-1", access_token: "token", institution_name: "First Platypus Bank")
    checking = item.accounts.create!(plaid_account_id: "acc-1", name: "Plaid Checking", account_type: "depository", subtype: "checking", current_balance: 1200)
    card = item.accounts.create!(plaid_account_id: "acc-2", name: "Plaid Credit Card", account_type: "credit", subtype: "credit card", current_balance: 200)
    [ [ 1.day.ago, 1000, 100 ], [ Date.current, 1200, 200 ] ].each do |date, checking_balance, card_balance|
      checking.balance_snapshots.create!(date: date.to_date, balance: checking_balance)
      card.balance_snapshots.create!(date: date.to_date, balance: card_balance)
    end

    get root_path

    expect(response.body).to include("$1,000.00", "Plaid Checking", "First Platypus Bank", "Net worth over time", "+$100.00")
    expect(response.body).not_to include("Sample data", "Link your real accounts", "Roth IRA")
    # With a history to chart, it comes before the breakdown.
    expect(response.body.index('id="net-worth-history-heading"')).to be < response.body.index('id="net-worth-heading"')
  end

  it "says history starts today when there's only one day of snapshots" do
    sign_in_as users(:one)
    item = users(:one).plaid_items.create!(item_id: "item-1", access_token: "token")
    account = item.accounts.create!(plaid_account_id: "acc-1", name: "Plaid Checking", account_type: "depository", subtype: "checking", current_balance: 100)
    account.balance_snapshots.create!(date: Date.current, balance: 100)

    get root_path

    expect(response.body).to include("Your history starts today")
    expect(response.body.index('id="net-worth-heading"')).to be < response.body.index('id="net-worth-history-heading"')
  end

  it "prompts users without connected accounts to link them" do
    sign_in_as users(:one)

    get root_path

    expect(response.body).to include("Link your real accounts", "Bank or credit card", "Investment account", "Sample data")
  end

  it "shows the net worth chart grouped by category on the dashboard" do
    sign_in_as users(:one)

    get root_path

    expect(response.body).to include("Net worth", "$93,358.70", "Sample data")
    expect(response.body).to include("Checking", "Savings", "Investments", "Credit cards")
    expect(response.body).to include("Joint Checking", "Roth IRA", "Rewards Credit Card", "3 accounts")
    expect(response.body.scan('data-donut-target="segment"').size).to eq(3)
  end

  it "shows net worth history for the chosen range, defaulting to 6 months" do
    sign_in_as users(:one)

    get root_path
    expect(response.body).to include("Net worth over time", "over the last 6 months")

    get root_path(range: "1y")
    expect(response.body).to include("over the last year")

    get root_path(range: "bogus")
    expect(response.body).to include("over the last 6 months")
  end

  it "draws one net worth line by default, or a line per category" do
    sign_in_as users(:one)

    get root_path
    expect(response.body.scan('data-line-chart-target="dot"').size).to eq(1)

    get root_path(view: "categories")
    expect(response.body.scan('data-line-chart-target="dot"').size).to eq(3)
    expect(response.body).to include('aria-label="Legend"')
  end

  it "leaves $0 accounts off the dashboard" do
    sign_in_as users(:one)
    item = users(:one).plaid_items.create!(item_id: "item-1", access_token: "token", institution_name: "First Platypus Bank")
    item.accounts.create!(plaid_account_id: "acc-1", name: "Plaid Checking", account_type: "depository", subtype: "checking", current_balance: 1200)
    item.accounts.create!(plaid_account_id: "acc-2", name: "Empty Savings", account_type: "depository", subtype: "savings", current_balance: 0)
    item.accounts.create!(plaid_account_id: "acc-3", name: "Paid Off Card", account_type: "credit", subtype: "credit card", current_balance: 0)

    get root_path

    expect(response.body).to include("Plaid Checking", "1 account")
    expect(response.body).not_to include("Empty Savings", "Paid Off Card", "Savings", "subtracted from net worth", "Sample data")
  end

  it "shows a $0 dashboard when every account is empty" do
    sign_in_as users(:one)
    item = users(:one).plaid_items.create!(item_id: "item-1", access_token: "token", institution_name: "First Platypus Bank")
    item.accounts.create!(plaid_account_id: "acc-1", name: "Empty Checking", account_type: "depository", subtype: "checking", current_balance: 0)

    get root_path

    expect(response).to have_http_status(:success)
    expect(response.body).not_to include("Empty Checking", "Sample data", "Link your real accounts")
  end

  it "has a full-screen menu for small screens, marking the current page" do
    sign_in_as users(:one)

    get root_path

    expect(response.body).to include('aria-label="Open menu"', '<dialog class="m-0 h-dvh', 'aria-label="Close menu"')
    menu = response.body[%r{<dialog[^>]*aria-label="Menu".*?</dialog>}m]
    expect(menu).to include("Overview", "Accounts", "Transactions", "Budgets", "Subscriptions", "Taxes", "Log out")
    expect(menu).to match(%r{<a [^>]*aria-current="page"[^>]*href="/">Overview</a>})
  end

  it "lets a finger slide across the net worth chart without scrolling the page sideways" do
    sign_in_as users(:one)
    item = users(:one).plaid_items.create!(item_id: "item-1", access_token: "token")
    account = item.accounts.create!(plaid_account_id: "acc-1", name: "Plaid Checking", account_type: "depository", subtype: "checking", current_balance: 100)
    [ 1.day.ago.to_date, Date.current ].each { |date| account.balance_snapshots.create!(date:, balance: 100) }

    get root_path

    expect(response.body).to include("touch-pan-y", "pointerdown->line-chart#move", "pointerdown@window->line-chart#dismiss")
  end
end
