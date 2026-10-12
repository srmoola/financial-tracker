require "rails_helper"

RSpec.describe AccountsHelper, type: :helper do
  it "spells out Plaid account subtypes" do
    expect(%w[ checking cd hsa ira 401k ].map { |subtype| helper.account_subtype_label(subtype) }).to eq([ "Checking", "CD", "HSA", "IRA", "401(k)" ])
    expect(helper.account_subtype_label("money market")).to eq("Money Market")
    expect(helper.account_subtype_label("credit card")).to eq("Credit Card")
    expect(helper.account_subtype_label("roth")).to eq("Roth IRA")
    expect(helper.account_subtype_label("roth 401k")).to eq("Roth 401(k)")
    expect(helper.account_subtype_label(nil)).to be_nil
  end

  it "sorts accounts in dashboard order and colors them by category" do
    account = ->(name, account_type, subtype) { SampleData::Account.new(name:, institution_name: "Bank", mask: "0000", account_type:, subtype:, balance: 1) }
    accounts = [ account.("Visa", "credit", "credit card"), account.("IRA", "investment", "ira"), account.("Savings", "depository", "savings"), account.("B Checking", "depository", "checking"), account.("A Checking", "depository", "checking") ]

    expect(helper.sorted_accounts(accounts).map(&:name)).to eq([ "A Checking", "B Checking", "Savings", "IRA", "Visa" ])
    expect(helper.account_group_color(accounts.first)).to be_nil
    expect(helper.account_group_color(accounts.last)).to eq(DonutChartHelper::CATEGORY_COLORS[:checking])
  end

  it "makes institution initials" do
    expect(helper.institution_initials("First Platypus Bank")).to eq("FP")
    expect(helper.institution_initials("Chase")).to eq("C")
    expect(helper.institution_initials(nil)).to eq("?")
  end
end
