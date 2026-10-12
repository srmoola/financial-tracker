require "rails_helper"

RSpec.describe AccountsHelper, type: :helper do
  it "spells out Plaid account subtypes" do
    expect(%w[ checking cd hsa ira 401k ].map { |subtype| helper.account_subtype_label(subtype) }).to eq([ "Checking", "CD", "HSA", "IRA", "401(k)" ])
    expect(helper.account_subtype_label("money market")).to eq("Money Market")
    expect(helper.account_subtype_label("credit card")).to eq("Credit Card")
    expect(helper.account_subtype_label(nil)).to be_nil
  end
end
