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

  def plaid_api_error(error_code)
    Plaid::ApiError.new(code: 400, response_body: { error_code: }.to_json)
  end
end

RSpec.configure do |config|
  config.include PlaidHelpers
end
