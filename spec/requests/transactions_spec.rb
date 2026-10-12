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

  describe "This month (the default)" do
    it "covers the current statement period of each card" do
      travel_to Date.new(2026, 10, 12) do
        card.update!(last_statement_issue_date: Date.new(2026, 9, 16))
        add_transaction(amount: 12.5, merchant: "After Statement", date: Date.new(2026, 9, 17))
        add_transaction(amount: 99, merchant: "Last Statement", date: Date.new(2026, 9, 16))

        get transactions_path

        expect(response.body).to include("This month, since Sep 17", "After Statement", "$12.50")
        expect(response.body).not_to include("Last Statement")
      end
    end

    it "lines longer ranges up with the card's statements" do
      travel_to Date.new(2026, 10, 12) do
        card.update!(last_statement_issue_date: Date.new(2026, 9, 15))
        add_transaction(amount: 30, merchant: "Start Of Range", date: Date.new(2026, 6, 16))
        add_transaction(amount: 40, merchant: "Before Range", date: Date.new(2026, 6, 15))

        get transactions_path(range: "3m")

        expect(response.body).to include("Your last 3 statements and this month, since Jun 16", "Start Of Range")
        expect(response.body).not_to include("Before Range")
      end
    end

    it "has an All range covering every transaction, saying how far back it goes" do
      travel_to Date.new(2026, 10, 12) do
        card.update!(last_statement_issue_date: Date.new(2026, 9, 15))
        add_transaction(amount: 25, merchant: "Two Years Ago", date: Date.new(2024, 10, 14))
        add_transaction(amount: 10, merchant: "Recent", date: Date.new(2026, 10, 1))

        get transactions_path(range: "all")

        expect(response.body).to include("All time, since Oct 14, 2024", "Two Years Ago", "Recent", "$35.00")
        expect(response.body).to match(%r{<a [^>]*tab-active[^>]*>All</a>})

        get transactions_path(range: "1y")
        expect(response.body).not_to include("Two Years Ago")
      end
    end

    it "starts on the 1st for cards without a statement date" do
      travel_to Date.new(2026, 10, 12) do
        add_transaction(amount: 5, merchant: "October Purchase", date: Date.new(2026, 10, 1))
        add_transaction(amount: 5, merchant: "September Purchase", date: Date.new(2026, 9, 30))

        get transactions_path

        expect(response.body).to include("since Oct 1", "October Purchase")
        expect(response.body).not_to include("September Purchase")
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
    expect(response.body).not_to include("Old Purchase")

    get transactions_path(range: "3m")
    expect(response.body).to include("Old Purchase", "$999.00")
  end

  describe "filtering by category" do
    before do
      add_transaction(amount: 12.5, merchant: "Coffee Shop", category: "FOOD_AND_DRINK")
      add_transaction(amount: 80, merchant: "Airline", category: "TRAVEL")
      add_transaction(amount: 3, merchant: "Mystery", category: nil)
    end

    it "lists only that category and shows a chip to clear it" do
      get transactions_path(range: "1m", category: "TRAVEL")

      expect(response.body).to include("Airline", "Clear the Travel filter", "Showing 1–1 of 1")
      expect(response.body).not_to include("Coffee Shop", "Mystery")
      # The donut still shows every category, and the selected one links back to all.
      expect(response.body).to include("Food &amp; drink", 'aria-label="Show all categories"')
    end

    it "supports uncategorized transactions" do
      get transactions_path(range: "1m", category: "uncategorized")

      expect(response.body).to include("Mystery")
      expect(response.body).not_to include("Coffee Shop", "Airline")
    end

    it "lists everything without its own slice under Other" do
      %w[ MEDICAL PERSONAL_CARE ENTERTAINMENT GENERAL_MERCHANDISE ].each_with_index do |category, index|
        add_transaction(amount: 100 + index, merchant: "Big #{category}", category:)
      end

      get transactions_path(range: "1m", category: "other")

      # Named slices: the five largest (four "Big" ones and Travel). Food and uncategorized fall into Other.
      expect(response.body).to include("Coffee Shop", "Mystery")
      expect(response.body).not_to include("Airline", "Big MEDICAL")
    end
  end

  it "paginates 25 per page with numbered pages, newest first" do
    30.times { |days_ago| add_transaction(amount: 1, merchant: "Shop #{days_ago}", date: Date.current - days_ago) }

    get transactions_path(range: "3m")
    expect(response.body).to include("Showing 1–25 of 30", "Shop 0", "Shop 24", 'aria-label="Page 2"', 'aria-label="Next page"')
    expect(response.body).not_to include("Shop 25")

    get transactions_path(range: "3m", page: 2)
    expect(response.body).to include("Showing 26–30 of 30", "Shop 25", "Shop 29", 'aria-current="page"')

    get transactions_path(range: "3m", page: 99)
    expect(response.body).to include("Showing 26–30 of 30")
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
