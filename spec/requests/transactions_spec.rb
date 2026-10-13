require "rails_helper"

RSpec.describe "Transactions page", type: :request do
  fixtures :users

  let(:item) { users(:one).plaid_items.create!(item_id: "item-1", access_token: "token", institution_name: "First Platypus Bank") }
  let(:card) { item.accounts.create!(plaid_account_id: "card-1", name: "Rewards Card", account_type: "credit", subtype: "credit card", mask: "3333") }

  def add_transaction(amount:, date: Date.current, merchant: "Coffee Shop", category: "FOOD_AND_DRINK", account: card, pending: false)
    account.transactions.create!(plaid_transaction_id: SecureRandom.hex(6), amount:, date:, merchant_name: merchant, category:, pending:)
  end

  # The page without the spending chart's popovers, which list purchases from the chart's own range.
  def body_outside_chart = response.body.gsub(%r{<template data-line-chart-target="detail".*?</template>}m, "")

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

  describe "This month (the default)" do
    it "covers the current statement period of each card" do
      travel_to Date.new(2026, 10, 12) do
        card.update!(last_statement_issue_date: Date.new(2026, 9, 16))
        add_transaction(amount: 12.5, merchant: "After Statement", date: Date.new(2026, 9, 17))
        add_transaction(amount: 99, merchant: "Last Statement", date: Date.new(2026, 9, 16))

        get transactions_path

        expect(response.body).to include("This month, since Sep 17", "After Statement", "$12.50")
        expect(body_outside_chart).not_to include("Last Statement")
      end
    end

    it "lines longer ranges up with the card's statements" do
      travel_to Date.new(2026, 10, 12) do
        card.update!(last_statement_issue_date: Date.new(2026, 9, 15))
        add_transaction(amount: 30, merchant: "Start Of Range", date: Date.new(2026, 6, 16))
        add_transaction(amount: 40, merchant: "Before Range", date: Date.new(2026, 6, 15))

        get transactions_path(range: "3m", list_range: "3m")

        expect(response.body).to include("Your last 3 statements and this month, since Jun 16", "Start Of Range")
        expect(body_outside_chart).not_to include("Before Range")
      end
    end

    it "has an All range covering every transaction, saying how far back it goes" do
      travel_to Date.new(2026, 10, 12) do
        card.update!(last_statement_issue_date: Date.new(2026, 9, 15))
        add_transaction(amount: 25, merchant: "Two Years Ago", date: Date.new(2024, 10, 14))
        add_transaction(amount: 10, merchant: "Recent", date: Date.new(2026, 10, 1))

        get transactions_path(range: "all", list_range: "all")

        expect(response.body).to include("All time, since Oct 14, 2024", "Two Years Ago", "Recent", "$35.00")
        expect(response.body).to match(%r{<a [^>]*tab-active[^>]*>All</a>})

        get transactions_path(range: "1y", list_range: "1y")
        expect(body_outside_chart).not_to include("Two Years Ago")
      end
    end

    it "starts on the 1st for cards without a statement date" do
      travel_to Date.new(2026, 10, 12) do
        add_transaction(amount: 5, merchant: "October Purchase", date: Date.new(2026, 10, 1))
        add_transaction(amount: 5, merchant: "September Purchase", date: Date.new(2026, 9, 30))

        get transactions_path

        expect(response.body).to include("since Oct 1", "October Purchase")
        expect(body_outside_chart).not_to include("September Purchase")
      end
    end

    it "prompts to enable statement dates for connections that need consent" do
      card
      item.update!(statement_dates_status: "needs_consent")

      get transactions_path

      expect(response.body).to include("Enable statement dates", "First Platypus Bank statement", item.id)
    end
  end

  it "shows spending by category and the list for a fixed range" do
    add_transaction(amount: 12.5, merchant: "Coffee Shop")
    add_transaction(amount: 80, merchant: "Airline", category: "TRAVEL", pending: true)
    add_transaction(amount: -200, merchant: nil, category: "LOAN_PAYMENTS")
    add_transaction(amount: 999, merchant: "Old Purchase", date: 2.months.ago.to_date)

    get transactions_path(range: "1m")

    expect(response.body).to include("Spending", "$92.50", "2 purchases", "Food &amp; drink", "Travel")
    expect(response.body).to include("Coffee Shop", "Airline", "Pending", "+$200.00", "Rewards Card •••• 3333", "Showing 1–3 of 3")
    expect(body_outside_chart).not_to include("Old Purchase")

    get transactions_path(range: "3m")
    expect(response.body).to include("Old Purchase", "$999.00")
  end

  it "shows Unknown merchant, with the masked statement text, when the card masked the description" do
    card.transactions.create!(plaid_transaction_id: "masked-1", amount: 63.57, date: Date.current, description: "*********-********", category: "GENERAL_MERCHANDISE")

    get transactions_path

    expect(response.body).to include("Unknown merchant", "· *********-********")
  end

  describe "filtering by category" do
    before do
      add_transaction(amount: 12.5, merchant: "Coffee Shop", category: "FOOD_AND_DRINK")
      add_transaction(amount: 80, merchant: "Airline", category: "TRAVEL")
      add_transaction(amount: 3, merchant: "Mystery", category: nil)
    end

    it "lists only that category, picked from the list's own menu of every category in the range" do
      get transactions_path(range: "1m", category: "TRAVEL")

      expect(response.body).to include("Airline", "Showing 1–1 of 1")
      expect(body_outside_chart).not_to include("Coffee Shop", "Mystery")
      expect(response.body).to include('aria-label="Filter by category"', '<option value="">All categories</option>', '<option selected="selected" value="TRAVEL">Travel</option>')
      expect(response.body).to include('<option value="FOOD_AND_DRINK">Food &amp; drink</option>', '<option value="uncategorized">Uncategorized</option>')
      # The donut still shows every category, with the filtered one selected.
      expect(response.body).to include("Food &amp; drink", 'data-donut-selected-value="0"')
    end

    it "lets a category picked on the donut filter the list, through its own button" do
      get transactions_path(range: "1m")

      expect(response.body).to include("Click a category to see its transactions.")
      expect(response.body).to match(%r{<a class="btn btn-sm btn-primary" hidden="hidden" data-donut-target="action" data-scroll-to="#transactions-heading" href="/transactions\?category=TRAVEL&amp;chart_range=6m&amp;list_range=1m&amp;range=1m&amp;spending_view=total">\s*See Travel transactions})
      expect(response.body).not_to include('href="/transactions?category=TRAVEL&amp;chart_range=6m&amp;list_range=1m&amp;range=1m&amp;spending_view=total" aria-label') # legend rows only select
    end

    it "supports uncategorized transactions" do
      get transactions_path(range: "1m", category: "uncategorized")

      expect(response.body).to include("Mystery")
      expect(body_outside_chart).not_to include("Coffee Shop", "Airline")
    end

    it "lists everything without its own slice under Other" do
      %w[ MEDICAL PERSONAL_CARE ENTERTAINMENT GENERAL_MERCHANDISE ].each_with_index do |category, index|
        add_transaction(amount: 100 + index, merchant: "Big #{category}", category:)
      end

      get transactions_path(range: "1m", category: "other")

      # Named slices: the five largest (four "Big" ones and Travel). Food and uncategorized fall into Other.
      expect(response.body).to include("Coffee Shop", "Mystery", '<option selected="selected" value="other">Other categories</option>')
      expect(body_outside_chart).not_to include("Airline", "Big MEDICAL")
    end
  end

  describe "spending over time" do
    before do
      travel_to Date.new(2026, 10, 12)
      card.update!(last_statement_issue_date: Date.new(2026, 9, 15))
      add_transaction(amount: 30, merchant: "Coffee", category: "FOOD_AND_DRINK", date: Date.new(2026, 8, 20))
      add_transaction(amount: 70, merchant: "Flight", category: "TRAVEL", date: Date.new(2026, 9, 20))
      add_transaction(amount: 12, merchant: "Lunch", category: "FOOD_AND_DRINK", date: Date.new(2026, 10, 2))
    end

    after { travel_back }

    it "has its own range, defaulting to 6 months of statement months" do
      get transactions_path

      expect(response.body).to include("Spending over time", "Total per statement month", "Aug 16 – Sep 15", "Sep 16 – Oct 12 (so far)")
      expect(response.body).to include("/transactions?chart_range=1y&amp;list_range=statement&amp;range=statement&amp;spending_view=total")
    end

    it "shows a running total by day for ranges under 6 months" do
      get transactions_path(chart_range: "3m")

      expect(response.body).to include("Running total by day since Jun 16", "Spent so far")
    end

    it "shows a line per category on request" do
      get transactions_path(spending_view: "total")
      expect(response.body.scan('data-line-chart-target="dot"').size).to eq(1)

      get transactions_path(range: "1y", spending_view: "categories")
      expect(response.body.scan('data-line-chart-target="dot"').size).to eq(2)
      expect(response.body).to include('aria-label="Legend"')
    end

    it "lists each point's top purchases for its popover" do
      get transactions_path(chart_range: "6m")

      expect(response.body).to include("Click to see the top purchases", 'data-line-chart-target="popover"')
      period = response.body[/<template data-line-chart-target="detail" data-index="5">.*?<\/template>/m]
      expect(period).to include("Aug 16 – Sep 15", "1 purchase", "Coffee", "Food &amp; drink · Aug 20", "$30.00")
    end

    it "charts every category even when the list is filtered, keeping the filter in its links" do
      get transactions_path(range: "1y", category: "TRAVEL", spending_view: "categories")

      expect(response.body).not_to include("Travel only")
      expect(response.body.scan('data-line-chart-target="dot"').size).to eq(2)
      expect(response.body).to include("Spending chart lines", "/transactions?category=TRAVEL&amp;chart_range=1y&amp;list_range=statement&amp;range=1y&amp;spending_view=categories")

      get transactions_path(range: "1y", category: "TRAVEL")
      expect(response.body).to include("Coffee", "$30.00") # a Food & drink purchase, in the chart's top purchases
    end

    it "keeps the other ranges and the chart's view when one range changes" do
      get transactions_path(range: "1m", list_range: "6m", spending_view: "categories", chart_range: "1y")

      expect(response.body).to include("/transactions?chart_range=1y&amp;list_range=6m&amp;range=3m&amp;spending_view=categories") # donut's 3M
      expect(response.body).to include("/transactions?chart_range=3m&amp;list_range=6m&amp;range=1m&amp;spending_view=categories") # chart's 3M
      expect(response.body).to include("/transactions?chart_range=1y&amp;list_range=1y&amp;range=1m&amp;spending_view=categories") # list's 1Y
    end
  end

  it "paginates 25 per page with numbered pages, newest first" do
    30.times { |days_ago| add_transaction(amount: 1, merchant: "Shop #{days_ago}", date: Date.current - days_ago) }

    get transactions_path(list_range: "3m")
    expect(response.body).to include("Showing 1–25 of 30", "Shop 0", "Shop 24", 'aria-label="Page 2"', 'aria-label="Next page"')
    expect(body_outside_chart).not_to include("Shop 25")
    expect(response.body).to include("/transactions?chart_range=6m&amp;list_range=3m&amp;page=2&amp;range=statement&amp;spending_view=total")

    get transactions_path(list_range: "3m", page: 2)
    expect(response.body).to include("Showing 26–30 of 30", "Shop 25", "Shop 29", 'aria-current="page"')

    get transactions_path(list_range: "3m", page: 99)
    expect(response.body).to include("Showing 26–30 of 30")
  end

  it "has a 1W range covering the last 7 days, today included, in the donut, chart and list" do
    travel_to Date.new(2026, 10, 13) do
      card.update!(last_statement_issue_date: Date.new(2026, 9, 15))
      add_transaction(amount: 15, merchant: "Within The Week", date: Date.new(2026, 10, 7))
      add_transaction(amount: 40, merchant: "Eight Days Ago", date: Date.new(2026, 10, 6))

      get transactions_path(range: "1w", list_range: "1w", chart_range: "1w")

      expect(response.body).to include("Last 7 days, since Oct 7", "Within The Week", "$15.00", "Showing 1–1 of 1")
      expect(response.body).to include("Running total by day since Oct 7")
      expect(body_outside_chart).not_to include("Eight Days Ago")
      expect(response.body).to match(%r{<a [^>]*tab-active[^>]*>1W</a>})
    end
  end

  it "says when there's nothing in the last 7 days" do
    add_transaction(amount: 15, merchant: "Long Ago", date: 3.weeks.ago.to_date)

    get transactions_path(range: "1w", list_range: "1w")

    expect(response.body).to include("No credit card purchases in the last 7 days.", "No transactions in the last 7 days.")
  end

  it "gives the list its own time range, separate from the spending summary's" do
    travel_to Date.new(2026, 10, 12) do
      card.update!(last_statement_issue_date: Date.new(2026, 9, 15))
      add_transaction(amount: 20, merchant: "Recent Purchase", date: Date.new(2026, 10, 1))
      add_transaction(amount: 70, merchant: "Older Purchase", date: Date.new(2026, 8, 20))

      get transactions_path(list_range: "3m")

      expect(response.body).to include("Showing 1–2 of 2", "Older Purchase", 'aria-label="Transactions time range"', 'aria-label="Spending time range"')
      expect(response.body).to include('<p class="mt-1 text-sm text-base-content/60" data-donut-target="detail">1 purchase</p>') # the donut is still This month

      get transactions_path(range: "3m")
      expect(response.body).to include("Showing 1–1 of 1", '<p class="mt-1 text-sm text-base-content/60" data-donut-target="detail">2 purchases</p>')
    end
  end

  describe "searching the list" do
    before do
      add_transaction(amount: 12, merchant: "Blue Bottle Coffee")
      add_transaction(amount: 30, merchant: "Whole Foods", category: "GENERAL_MERCHANDISE")
      card.transactions.create!(plaid_transaction_id: "no-merchant", amount: 9, date: Date.current, description: "LOCAL BAKERY 123", category: "FOOD_AND_DRINK")
      card.transactions.create!(plaid_transaction_id: "noted", amount: 45, date: Date.current, merchant_name: "Amazon", note: "Birthday gift for mom", category: "GENERAL_MERCHANDISE")
    end

    it "finds transactions by merchant, statement description or note, in any case" do
      get transactions_path(q: "coffee")
      expect(response.body).to include("Blue Bottle Coffee", "Showing 1–1 of 1", 'value="coffee"')
      expect(body_outside_chart).not_to include("Whole Foods", "LOCAL BAKERY")

      get transactions_path(q: "bakery")
      expect(response.body).to include("LOCAL BAKERY 123", "Showing 1–1 of 1")

      get transactions_path(q: "BIRTHDAY")
      expect(response.body).to include("Amazon", "Birthday gift for mom", "Showing 1–1 of 1")
    end

    it "searches within the category and keeps the search in the page's links" do
      get transactions_path(q: "o", category: "GENERAL_MERCHANDISE")

      expect(response.body).to include("Whole Foods", "Amazon", "Showing 1–2 of 2")
      expect(response.body).to include("/transactions?category=GENERAL_MERCHANDISE&amp;chart_range=6m&amp;list_range=1m&amp;q=o&amp;range=statement&amp;spending_view=total") # the list's 1M tab
    end

    it "says when nothing matches, offering to search all of them" do
      get transactions_path(q: "zzz")

      expect(response.body).to include("No transactions matching “zzz” this statement period.", "Search all transactions", "list_range=all&amp;q=zzz")
    end
  end

  it "never shows another user's transactions" do
    add_transaction(amount: 10, merchant: "Mine")
    other_card = users(:two).plaid_items.create!(item_id: "item-2", access_token: "token-2")
      .accounts.create!(plaid_account_id: "card-2", name: "Their Card", account_type: "credit", subtype: "credit card")
    add_transaction(amount: 77, merchant: "Theirs", account: other_card)

    get transactions_path(range: "1m")

    expect(response.body).to include("Mine")
    expect(response.body).not_to include("Theirs", "$77.00")
  end

  it "shows this statement period's spending on the dashboard card" do
    add_transaction(amount: 42)

    get root_path

    expect(response.body).to include("$42.00", "spent on credit cards this statement period")
  end
end
