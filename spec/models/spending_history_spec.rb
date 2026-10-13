require "rails_helper"

RSpec.describe SpendingHistory do
  fixtures :users

  let(:today) { Date.new(2026, 10, 12) }
  let(:item) { users(:one).plaid_items.create!(item_id: "item-1", access_token: "token") }
  let(:card) { item.accounts.create!(plaid_account_id: "card-1", name: "Card", account_type: "credit", subtype: "credit card", last_statement_issue_date: Date.new(2026, 9, 15)) }

  def spend(amount, date, category = "FOOD_AND_DRINK", account: card)
    account.transactions.create!(plaid_transaction_id: SecureRandom.hex(4), amount:, date:, category:)
  end

  def history(periods_back, keys = %w[ FOOD_AND_DRINK TRAVEL ])
    SpendingHistory.new(Transaction.where(account: card).where("transactions.amount > 0"), cards: [ card ], category_keys: keys, periods_back:, today:)
  end

  it "builds a running total for each day of the current statement period" do
    spend(10, Date.new(2026, 9, 16))
    spend(5, Date.new(2026, 9, 18), "TRAVEL")
    spend(2, Date.new(2026, 9, 18))

    result = history(0)

    expect(result).to be_daily
    expect(result.points.first.date).to eq(Date.new(2026, 9, 16))
    expect(result.points.last.date).to eq(today)
    by_date = result.points.index_by(&:date)
    expect(by_date[Date.new(2026, 9, 17)].total).to eq(10)
    expect(by_date[Date.new(2026, 9, 18)]).to have_attributes(total: 17, label: "Sep 18, 2026")
    expect(by_date[Date.new(2026, 9, 18)].by_category).to eq("FOOD_AND_DRINK" => 12, "TRAVEL" => 5)
    expect(result.points.last.total).to eq(17)
  end

  it "keeps going day by day for ranges under 6 months, from the first statement period in range" do
    spend(30, Date.new(2026, 7, 20))
    spend(5, Date.new(2026, 10, 1))

    result = history(3)

    expect(result).to be_daily
    expect(result.points.first.date).to eq(Date.new(2026, 6, 16))
    expect(result.points.index_by(&:date)[Date.new(2026, 7, 20)].total).to eq(30)
    expect(result.points.last.total).to eq(35)
  end

  it "totals each statement period for 6 months and longer, oldest first, with the current one marked so far" do
    spend(30, Date.new(2026, 8, 16))
    spend(20, Date.new(2026, 9, 15))
    spend(7, Date.new(2026, 9, 16), "TRAVEL")
    spend(4, Date.new(2026, 10, 1), "ENTERTAINMENT")

    result = history(6)

    expect(result).not_to be_daily
    expect(result.points.size).to eq(7)
    expect(result.points.last(2).map(&:label)).to eq([ "Aug 16 – Sep 15", "Sep 16 – Oct 12 (so far)" ])
    expect(result.points.last(2).map(&:total)).to eq([ 50, 11 ])
    expect(result.points.last.by_category).to eq("TRAVEL" => 7, :other => 4)
  end

  it "goes back as far as the oldest purchase for All" do
    spend(1, Date.new(2026, 6, 20))

    result = history(nil)

    expect(result.points.size).to eq(4) # Jun 16, Jul 16, Aug 16 and the current Sep 16 period
    expect(result.points.first.label).to eq("Jun 16 – Jul 15")
  end

  it "keeps each day's largest purchases, biggest first" do
    6.times { |index| spend(10 + index, Date.new(2026, 10, 2)) }
    spend(99, Date.new(2026, 10, 3))

    by_date = history(0).points.index_by(&:date)

    expect(by_date[Date.new(2026, 10, 2)].purchase_count).to eq(6)
    expect(by_date[Date.new(2026, 10, 2)].top_purchases.map(&:amount)).to eq([ 15, 14, 13, 12, 11 ])
    expect(by_date[Date.new(2026, 10, 3)].top_purchases.map(&:amount)).to eq([ 99 ])
    expect(by_date[Date.new(2026, 10, 4)]).to have_attributes(purchase_count: 0, top_purchases: [])
  end

  it "keeps each statement period's largest purchases" do
    spend(30, Date.new(2026, 8, 16))
    spend(20, Date.new(2026, 9, 15))
    spend(7, Date.new(2026, 9, 16))

    points = history(6).points

    expect(points[-2].top_purchases.map(&:amount)).to eq([ 30, 20 ])
    expect(points[-1].top_purchases.map(&:amount)).to eq([ 7 ])
  end

  it "goes day by day from a start date when given one, e.g. the last 7 days" do
    spend(9, Date.new(2026, 10, 8))
    spend(5, Date.new(2026, 10, 12))

    result = SpendingHistory.new(Transaction.where(account: card), cards: [ card ], category_keys: %w[ FOOD_AND_DRINK ], periods_back: nil, since: Date.new(2026, 10, 6), today:)

    expect(result).to be_daily
    expect(result.points.map(&:date)).to eq((Date.new(2026, 10, 6)..today).to_a)
    expect(result.points.last.total).to eq(14)
  end

  it "is empty without purchases" do
    expect(history(0)).to be_empty
  end
end
