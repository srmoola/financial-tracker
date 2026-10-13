require "rails_helper"

RSpec.describe Account, "syncing transactions" do
  fixtures :users

  let(:api) { stub_plaid_api }
  let(:item) { users(:one).plaid_items.create!(item_id: "item-1", access_token: "access-1") }
  let(:card) { item.accounts.create!(plaid_account_id: "card-1", name: "Credit Card", account_type: "credit", subtype: "credit card") }

  it "pages through /transactions/sync for just this account, saving transactions and the cursor" do
    allow(api).to receive(:transactions_sync).and_return(
      plaid_sync_response(added: [ plaid_transaction(id: "t1", account_id: "card-1", amount: 4.5, logo_url: "https://logos.example/coffee.png", website: "coffee.example") ], next_cursor: "page-2", has_more: true),
      plaid_sync_response(added: [ plaid_transaction(id: "t2", account_id: "card-1", amount: -100, merchant_name: nil, name: "PAYMENT", category: "LOAN_PAYMENTS") ], next_cursor: "done")
    )

    card.sync_transactions!

    expect(api).to have_received(:transactions_sync).twice
    expect(api).to have_received(:transactions_sync).with(having_attributes(cursor: nil, access_token: "access-1", options: having_attributes(account_id: "card-1")))
    expect(api).to have_received(:transactions_sync).with(having_attributes(cursor: "page-2"))
    expect(card.reload.transaction_sync_cursor).to eq("done")
    expect(card.transactions.find_by!(plaid_transaction_id: "t1")).to have_attributes(
      amount: 4.5, merchant_name: "Coffee Shop", description: "COFFEE SHOP 123", category: "FOOD_AND_DRINK",
      date: Date.new(2026, 10, 1), currency_code: "USD", payment_channel: "in store", latitude: 40.7, longitude: -74.0, pending: false,
      logo_url: "https://logos.example/coffee.png", website: "coffee.example"
    )
    expect(card.transactions.find_by!(plaid_transaction_id: "t2")).to have_attributes(amount: -100, merchant_name: nil, description: "PAYMENT")
  end

  it "fills in logos and websites on saved transactions when syncing from the start again, keeping what the user set" do
    saved = card.transactions.create!(plaid_transaction_id: "t1", amount: 4.5, date: Date.new(2026, 10, 1), category_override: "TRAVEL", note: "Work trip", created_at: 1.month.ago)
    allow(api).to receive(:transactions_sync).and_return(
      plaid_sync_response(added: [ plaid_transaction(id: "t1", account_id: "card-1", amount: 4.5, logo_url: "https://logos.example/coffee.png", website: "coffee.example") ])
    )

    expect { card.sync_transactions! }.not_to change(Transaction, :count)

    expect(saved.reload).to have_attributes(logo_url: "https://logos.example/coffee.png", website: "coffee.example", category_override: "TRAVEL", note: "Work trip")
    expect(saved.created_at).to be < 1.week.ago # still arrived when it first did, so it isn't "new"
  end

  it "continues from the saved cursor, applying changes and removals" do
    card.transactions.create!(plaid_transaction_id: "t1", amount: 4.5, date: Date.new(2026, 10, 1), pending: true)
    card.transactions.create!(plaid_transaction_id: "t-gone", amount: 9, date: Date.new(2026, 10, 1))
    card.update!(transaction_sync_cursor: "saved")
    allow(api).to receive(:transactions_sync).and_return(
      plaid_sync_response(modified: [ plaid_transaction(id: "t1", account_id: "card-1", amount: 5.25) ], removed: [ "t-gone" ], next_cursor: "newer")
    )

    card.sync_transactions!

    expect(api).to have_received(:transactions_sync).with(having_attributes(cursor: "saved"))
    expect(card.transactions.pluck(:plaid_transaction_id, :amount, :pending)).to eq([ [ "t1", 5.25, false ] ])
    expect(card.reload.transaction_sync_cursor).to eq("newer")
  end

  it "keeps the user's category, note and budget exclusions when a pending charge posts" do
    pending = card.transactions.create!(plaid_transaction_id: "pending-1", amount: 64.2, date: Date.new(2026, 10, 1), pending: true, category: "GENERAL_MERCHANDISE", category_override: "FOOD_AND_DRINK", note: "Weekly groceries")
    budget = card.plaid_item.user.budgets.create!(name: "Food", amount: 300, categories: %w[ FOOD_AND_DRINK ])
    budget.exclusions.create!(purchase: pending)
    posted = plaid_transaction(id: "posted-1", account_id: "card-1", amount: 64.2, category: "GENERAL_MERCHANDISE")
    posted.pending_transaction_id = "pending-1"
    allow(api).to receive(:transactions_sync).and_return(plaid_sync_response(added: [ posted ], removed: [ "pending-1" ]))

    card.sync_transactions!

    expect(card.transactions.pluck(:plaid_transaction_id, :category_override, :note, :pending)).to eq([ [ "posted-1", "FOOD_AND_DRINK", "Weekly groceries", false ] ])
    expect(budget.exclusions.sole.purchase.plaid_transaction_id).to eq("posted-1")
  end

  it "never overwrites the user's category when Plaid updates a transaction" do
    card.transactions.create!(plaid_transaction_id: "t1", amount: 10, date: Date.new(2026, 10, 1), category: "GENERAL_MERCHANDISE", category_override: "FOOD_AND_DRINK")
    allow(api).to receive(:transactions_sync).and_return(plaid_sync_response(modified: [ plaid_transaction(id: "t1", account_id: "card-1", amount: 10, category: "TRAVEL") ]))

    card.sync_transactions!

    expect(card.transactions.sole).to have_attributes(category: "TRAVEL", category_override: "FOOD_AND_DRINK")
  end

  it "starts over from the original cursor when Plaid's data changes mid-pagination" do
    card.update!(transaction_sync_cursor: "start")
    calls = 0
    allow(api).to receive(:transactions_sync) do |request|
      calls += 1
      case calls
      when 1 then plaid_sync_response(added: [ plaid_transaction(id: "stale", account_id: "card-1", amount: 1) ], next_cursor: "page-2", has_more: true)
      when 2 then raise plaid_api_error("TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION")
      else
        expect(request.cursor).to eq("start")
        plaid_sync_response(added: [ plaid_transaction(id: "fresh", account_id: "card-1", amount: 2) ], next_cursor: "end")
      end
    end

    card.sync_transactions!

    expect(card.transactions.pluck(:plaid_transaction_id)).to eq([ "fresh" ])
    expect(card.reload.transaction_sync_cursor).to eq("end")
  end

  it "leaves everything untouched when Plaid fails" do
    card.update!(transaction_sync_cursor: "saved")
    allow(api).to receive(:transactions_sync).and_raise(plaid_api_error("ITEM_LOGIN_REQUIRED"))

    expect { card.sync_transactions! }.to raise_error(Plaid::ApiError)
    expect(card.reload.transaction_sync_cursor).to eq("saved")
  end

  it "syncs balances for every account but transactions only for credit cards" do
    checking = item.accounts.create!(plaid_account_id: "checking-1", name: "Checking", account_type: "depository", subtype: "checking")
    allow(api).to receive(:accounts_get).and_return(plaid_accounts_response([
      plaid_account(id: "card-1", type: "credit", subtype: "credit card", current: 50),
      plaid_account(id: "checking-1", type: "depository", subtype: "checking", current: 500)
    ]))
    allow(api).to receive(:transactions_sync).and_return(plaid_sync_response)
    allow(api).to receive(:liabilities_get).and_raise(plaid_api_error("NO_LIABILITY_ACCOUNTS"))
    allow(api).to receive(:institutions_get_by_id).and_raise(plaid_api_error("INSTITUTION_NOT_FOUND"))
    card

    item.sync!

    expect(checking.reload.current_balance).to eq(500)
    expect(api).to have_received(:transactions_sync).once.with(having_attributes(options: having_attributes(account_id: "card-1")))
  end
end
