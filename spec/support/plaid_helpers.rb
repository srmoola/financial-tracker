# Fakes the Plaid API in specs with the gem's own request/response models.
module PlaidHelpers
  def stub_plaid_api
    instance_double(Plaid::PlaidApi).tap { |api| allow(PlaidClient).to receive(:api).and_return(api) }
  end

  def plaid_account(id:, type:, subtype:, current:, name: "Account #{id}", mask: "0000", available: nil, limit: nil)
    Plaid::AccountBase.new(
      account_id: id, name:, mask:, type:, subtype:,
      balances: Plaid::AccountBalance.new(current:, available:, limit:, iso_currency_code: "USD")
    )
  end

  def plaid_accounts_response(accounts, institution_name: "First Platypus Bank")
    Plaid::AccountsGetResponse.new(
      accounts:,
      item: Plaid::Item.new(item_id: "item-1", institution_id: "ins_109508", institution_name:),
      request_id: "request-1"
    )
  end

  def plaid_transaction(id:, account_id:, amount:, date: Date.new(2026, 10, 1), merchant_name: "Coffee Shop", name: "COFFEE SHOP 123", category: "FOOD_AND_DRINK", pending: false,
    logo_url: nil, website: nil)
    Plaid::Transaction.new(
      transaction_id: id, account_id:, amount:, iso_currency_code: "USD", merchant_name:, name:, date:, logo_url:, website:,
      pending:, pending_transaction_id: nil, payment_channel: "in store",
      personal_finance_category: Plaid::PersonalFinanceCategory.new(primary: category, detailed: "#{category}_OTHER"),
      location: Plaid::Location.new(lat: 40.7, lon: -74.0)
    )
  end

  def plaid_sync_response(added: [], modified: [], removed: [], next_cursor: "cursor-1", has_more: false)
    Plaid::TransactionsSyncResponse.new(
      added:, modified:, next_cursor:, has_more:, request_id: "request-1", accounts: [],
      removed: removed.map { |id| Plaid::RemovedTransaction.new(transaction_id: id) },
      transactions_update_status: "HISTORICAL_UPDATE_COMPLETE"
    )
  end

  def plaid_api_error(error_code)
    Plaid::ApiError.new(code: 400, response_body: { error_code: }.to_json)
  end
end

RSpec.configure do |config|
  config.include PlaidHelpers
end
