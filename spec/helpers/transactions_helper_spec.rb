require "rails_helper"

RSpec.describe TransactionsHelper, type: :helper do
  it "shows the first, last and current pages, with gaps in between" do
    expect(helper.page_window(1, 1)).to eq([ 1 ])
    expect(helper.page_window(1, 3)).to eq([ 1, 2, 3 ])
    expect(helper.page_window(1, 9)).to eq([ 1, 2, :gap, 9 ])
    expect(helper.page_window(5, 9)).to eq([ 1, :gap, 4, 5, 6, :gap, 9 ])
    expect(helper.page_window(9, 9)).to eq([ 1, :gap, 8, 9 ])
    expect(helper.page_window(3, 9)).to eq([ 1, 2, 3, 4, :gap, 9 ])
  end

  describe "#statement_range_heading" do
    let(:card) { Account.new(last_statement_issue_date: Date.new(2026, 9, 15)) }

    around { |example| travel_to(Date.new(2026, 10, 12)) { example.run } }

    it "describes what each range covers and when it starts" do
      expect(helper.statement_range_heading([ card ], 0)).to eq("This month, since Sep 16")
      expect(helper.statement_range_heading([ card ], 1)).to eq("Your last statement and this month, since Aug 16")
      expect(helper.statement_range_heading([ card ], 3)).to eq("Your last 3 statements and this month, since Jun 16")
      expect(helper.statement_range_heading([ card ], 12)).to eq("Your last 12 statements and this month, since Sep 16, 2025")
    end

    it "speaks generally when cards start on different days" do
      other = Account.new(last_statement_issue_date: Date.new(2026, 10, 2))

      expect(helper.statement_range_heading([ card, other ], 3)).to eq("Your last 3 statements and this month, since each card's statement date")
    end
  end
end
