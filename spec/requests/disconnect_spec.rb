require "rails_helper"

RSpec.describe "Disconnecting a bank", type: :request do
  fixtures :users

  let(:api) { stub_plaid_api }
  let!(:item) { users(:one).plaid_items.create!(item_id: "item-1", access_token: "access-1", institution_name: "Capital One") }

  before do
    item.accounts.create!(plaid_account_id: "card-1", name: "Quicksilver", account_type: "credit", subtype: "credit card", mask: "7513")
    sign_in_as users(:one)
  end

  it "asks for confirmation on the Accounts page, saying what will be removed" do
    get accounts_path

    expect(response.body).to include("Disconnect Capital One?", "This removes 1 account from Financial Tracker", "Plaid counts that as a new connection")
  end

  it "disconnects the bank and returns to the Accounts page" do
    allow(api).to receive(:item_remove)

    delete plaid_item_path(item)

    expect(response).to redirect_to(accounts_path)
    expect(flash[:notice]).to eq("Disconnected Capital One.")
    expect(PlaidItem.exists?(item.id)).to be(false)
  end

  it "says so and keeps the bank if Plaid fails" do
    allow(api).to receive(:item_remove).and_raise(plaid_api_error("INTERNAL_SERVER_ERROR"))

    delete plaid_item_path(item)

    expect(response).to redirect_to(accounts_path)
    expect(flash[:alert]).to eq("Couldn't disconnect Capital One. Please try again.")
    expect(PlaidItem.exists?(item.id)).to be(true)
  end

  it "can't disconnect someone else's bank" do
    other = users(:two).plaid_items.create!(item_id: "item-2", access_token: "access-2", institution_name: "Their Bank")

    delete plaid_item_path(other)

    expect(response).to have_http_status(:not_found)
    expect(PlaidItem.exists?(other.id)).to be(true)
  end
end
