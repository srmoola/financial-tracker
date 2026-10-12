require "rails_helper"

RSpec.describe "Connecting accounts with Plaid", type: :request do
  fixtures :users

  let(:api) { stub_plaid_api }

  before { sign_in_as users(:one) }

  describe "POST /plaid/link_tokens" do
    before { allow(api).to receive(:link_token_create).and_return(Plaid::LinkTokenCreateResponse.new(link_token: "link-sandbox-1")) }

    it "creates a bank link token with Transactions, 90 days of history and bank/card filters" do
      post plaid_link_tokens_path, params: { kind: "bank" }, as: :json

      expect(response.parsed_body).to eq("link_token" => "link-sandbox-1")
      expect(api).to have_received(:link_token_create) do |request|
        expect(request.products).to eq([ "transactions" ])
        expect(request.transactions.days_requested).to eq(90)
        expect(request.account_filters.depository.account_subtypes).to eq([ "all" ])
        expect(request.account_filters.credit.account_subtypes).to eq([ "credit card" ])
        expect(request.account_filters.investment).to be_nil
        expect(request.user.client_user_id).to eq(users(:one).id)
      end
    end

    it "creates an investment link token with Investments and only investment accounts" do
      post plaid_link_tokens_path, params: { kind: "investment" }, as: :json

      expect(api).to have_received(:link_token_create) do |request|
        expect(request.products).to eq([ "investments" ])
        expect(request.account_filters.investment.account_subtypes).to eq([ "all" ])
        expect(request.account_filters.depository).to be_nil
      end
    end

    it "rejects an unknown kind" do
      post plaid_link_tokens_path, params: { kind: "loan" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns an error message when Plaid fails" do
      allow(api).to receive(:link_token_create).and_raise(plaid_api_error("INVALID_API_KEYS"))

      post plaid_link_tokens_path, params: { kind: "bank" }, as: :json

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body["error"]).to include("Couldn't start connecting")
    end
  end

  describe "POST /plaid_items" do
    before do
      allow(api).to receive(:item_public_token_exchange)
        .and_return(Plaid::ItemPublicTokenExchangeResponse.new(access_token: "access-sandbox-1", item_id: "item-1"))
      allow(api).to receive(:accounts_get).and_return(plaid_accounts_response([
        plaid_account(id: "acc-1", type: "depository", subtype: "checking", current: 100)
      ]))
    end

    it "connects the account and sends the user to the dashboard" do
      expect {
        post plaid_items_path, params: { public_token: "public-sandbox-1", from: "onboarding" }, as: :json
      }.to change(users(:one).accounts, :count).by(1)

      expect(response.parsed_body).to eq("redirect_url" => root_path)
      expect(flash[:notice]).to eq("Connected First Platypus Bank.")
    end

    it "returns to the Accounts page when connecting from there" do
      post plaid_items_path, params: { public_token: "public-sandbox-1", from: "accounts" }, as: :json

      expect(response.parsed_body).to eq("redirect_url" => accounts_path)
    end

    it "returns an error message when the exchange fails" do
      allow(api).to receive(:item_public_token_exchange).and_raise(plaid_api_error("INVALID_PUBLIC_TOKEN"))

      expect {
        post plaid_items_path, params: { public_token: "bad" }, as: :json
      }.not_to change(PlaidItem, :count)

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body["error"]).to include("Couldn't finish connecting")
    end
  end

  it "requires login" do
    sign_out

    post plaid_link_tokens_path, params: { kind: "bank" }, as: :json

    expect(response).to redirect_to(new_session_path)
  end
end
