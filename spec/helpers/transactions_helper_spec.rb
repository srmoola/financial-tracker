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
end
