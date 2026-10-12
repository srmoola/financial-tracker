require "rails_helper"

RSpec.describe "Credit card statement dates" do
  fixtures :users

  let(:api) { stub_plaid_api }
  let(:item) { users(:one).plaid_items.create!(item_id: "item-1", access_token: "access-1") }
  let!(:card) { item.accounts.create!(plaid_account_id: "card-1", name: "Card", account_type: "credit", subtype: "credit card") }

  def liabilities_response(dates)
    Plaid::LiabilitiesGetResponse.new(
      accounts: [], item: Plaid::Item.new(item_id: "item-1"), request_id: "request-1",
      liabilities: Plaid::LiabilitiesObject.new(credit: dates.map { |id, date| Plaid::CreditCardLiability.new(account_id: id, last_statement_issue_date: date) })
    )
  end

  describe "PlaidItem#sync_statement_dates!" do
    it "saves each card's last statement date from Plaid Liabilities" do
      allow(api).to receive(:liabilities_get).and_return(liabilities_response("card-1" => Date.new(2026, 9, 16)))

      item.sync_statement_dates!

      expect(api).to have_received(:liabilities_get).with(having_attributes(access_token: "access-1", options: having_attributes(account_ids: [ "card-1" ])))
      expect(card.reload.last_statement_issue_date).to eq(Date.new(2026, 9, 16))
      expect(item.reload.statement_dates_status).to eq("available")
    end

    it "asks for consent when the connection hasn't allowed Liabilities yet" do
      allow(api).to receive(:liabilities_get).and_raise(plaid_api_error("ADDITIONAL_CONSENT_REQUIRED"))

      item.sync_statement_dates!

      expect(item.reload.statement_dates_status).to eq("needs_consent")
    end

    it "gives up if Liabilities still isn't available after consent" do
      allow(api).to receive(:liabilities_get).and_raise(plaid_api_error("PRODUCTS_NOT_SUPPORTED"))

      item.sync_statement_dates!(after_consent: true)

      expect(item.reload.statement_dates_status).to eq("unsupported")
    end

    it "marks connections without liability accounts as unsupported" do
      allow(api).to receive(:liabilities_get).and_raise(plaid_api_error("NO_LIABILITY_ACCOUNTS"))

      item.sync_statement_dates!

      expect(item.reload.statement_dates_status).to eq("unsupported")
    end

    it "raises other errors" do
      allow(api).to receive(:liabilities_get).and_raise(plaid_api_error("ITEM_LOGIN_REQUIRED"))

      expect { item.sync_statement_dates! }.to raise_error(Plaid::ApiError)
    end
  end

  describe "PlaidItem#sync!" do
    before do
      allow(api).to receive(:accounts_get).and_return(plaid_accounts_response([ plaid_account(id: "card-1", type: "credit", subtype: "credit card", current: 10) ]))
      allow(api).to receive(:transactions_sync).and_return(plaid_sync_response)
      allow(api).to receive(:liabilities_get).and_return(liabilities_response("card-1" => Date.new(2026, 9, 16)))
    end

    it "fetches statement dates along with balances and transactions" do
      item.sync!

      expect(card.reload.last_statement_issue_date).to eq(Date.new(2026, 9, 16))
    end

    it "doesn't keep asking Plaid while the connection needs consent" do
      item.update!(statement_dates_status: "needs_consent")

      item.sync!

      expect(api).not_to have_received(:liabilities_get)
    end
  end

  describe "Account#current_statement_start" do
    let(:today) { Date.new(2026, 10, 12) }

    it "starts the day after the last statement" do
      card.last_statement_issue_date = Date.new(2026, 9, 16)
      expect(card.current_statement_start(today:)).to eq(Date.new(2026, 9, 17))
    end

    it "rolls a stale statement date forward a month at a time" do
      card.last_statement_issue_date = Date.new(2026, 7, 16)
      expect(card.current_statement_start(today:)).to eq(Date.new(2026, 9, 17))
    end

    it "falls back to the 1st of the month without a statement date" do
      expect(card.current_statement_start(today:)).to eq(Date.new(2026, 10, 1))
    end
  end

  it "Transaction.in_current_statements uses each card's own statement period" do
    other_card = item.accounts.create!(plaid_account_id: "card-2", name: "Other card", account_type: "credit", subtype: "credit card")
    travel_to(Date.new(2026, 10, 12)) do
      card.update!(last_statement_issue_date: Date.new(2026, 9, 16))
      other_card.update!(last_statement_issue_date: Date.new(2026, 10, 2))
      card.transactions.create!(plaid_transaction_id: "in-1", amount: 1, date: Date.new(2026, 9, 20))
      card.transactions.create!(plaid_transaction_id: "out-1", amount: 1, date: Date.new(2026, 9, 16))
      other_card.transactions.create!(plaid_transaction_id: "in-2", amount: 1, date: Date.new(2026, 10, 3))
      other_card.transactions.create!(plaid_transaction_id: "out-2", amount: 1, date: Date.new(2026, 9, 20))

      expect(Transaction.in_current_statements([ card, other_card ]).pluck(:plaid_transaction_id)).to contain_exactly("in-1", "in-2")
    end
  end
end
