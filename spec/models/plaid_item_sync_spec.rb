require "rails_helper"

RSpec.describe PlaidItem, "connecting and syncing balances" do
  fixtures :users

  let(:api) { stub_plaid_api }
  let(:today) { Date.new(2026, 10, 12) }

  it "exchanges the public token, saves the Item and pulls in its accounts" do
    allow(api).to receive(:item_public_token_exchange)
      .and_return(Plaid::ItemPublicTokenExchangeResponse.new(access_token: "access-sandbox-1", item_id: "item-1"))
    allow(api).to receive(:accounts_get).and_return(plaid_accounts_response([
      plaid_account(id: "acc-checking", name: "Plaid Checking", type: "depository", subtype: "checking", current: 110, available: 100),
      plaid_account(id: "acc-card", name: "Plaid Credit Card", type: "credit", subtype: "credit card", current: 410, available: 1590, limit: 2000)
    ]))

    item = nil
    expect { item = PlaidItem.connect!(user: users(:one), public_token: "public-sandbox-1") }
      .to have_enqueued_job(SyncPlaidItemJob).with(kind_of(PlaidItem))

    expect(api).to have_received(:item_public_token_exchange).with(having_attributes(public_token: "public-sandbox-1"))
    expect(item.reload).to have_attributes(item_id: "item-1", access_token: "access-sandbox-1", institution_name: "First Platypus Bank", institution_id: "ins_109508")
    expect(item.last_synced_at).to be_present
    expect(item.accounts.order(:name).map { |account| [ account.name, account.account_type, account.subtype, account.current_balance ] }).to eq([
      [ "Plaid Checking", "depository", "checking", 110 ],
      [ "Plaid Credit Card", "credit", "credit card", 410 ]
    ])
    expect(item.accounts.find_by!(plaid_account_id: "acc-card")).to have_attributes(available_balance: 1590, credit_limit: 2000, mask: "0000", currency_code: "USD")
  end

  context "with an existing Item" do
    let(:item) { users(:one).plaid_items.create!(item_id: "item-1", access_token: "access-sandbox-1") }

    it "records one balance snapshot per account per day, updating it on a re-sync" do
      allow(api).to receive(:accounts_get).and_return(
        plaid_accounts_response([ plaid_account(id: "acc-1", type: "depository", subtype: "savings", current: 500) ]),
        plaid_accounts_response([ plaid_account(id: "acc-1", type: "depository", subtype: "savings", current: 650) ])
      )

      item.sync_balances!(today:)
      item.sync_balances!(today:)

      account = item.accounts.sole
      expect(account.current_balance).to eq(650)
      expect(account.balance_snapshots.map { |snapshot| [ snapshot.date, snapshot.balance ] }).to eq([ [ today, 650 ] ])
    end

    it "skips account types the dashboard doesn't handle" do
      allow(api).to receive(:accounts_get).and_return(plaid_accounts_response([
        plaid_account(id: "acc-loan", type: "loan", subtype: "student", current: 9000),
        plaid_account(id: "acc-brokerage", type: "investment", subtype: "brokerage", current: 1000)
      ]))

      item.sync_balances!(today:)

      expect(item.accounts.pluck(:plaid_account_id)).to eq([ "acc-brokerage" ])
    end

    it "doesn't record a snapshot when Plaid has no current balance" do
      allow(api).to receive(:accounts_get).and_return(plaid_accounts_response([
        plaid_account(id: "acc-1", type: "depository", subtype: "checking", current: nil)
      ]))

      item.sync_balances!(today:)

      expect(item.accounts.sole.balance_snapshots).to be_empty
    end
  end
end
