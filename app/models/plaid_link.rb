# Link tokens for opening Plaid Link. Banks/credit cards and investment accounts
# are linked separately: Plaid only lists institutions that support every
# requested product, so asking for Transactions would hide investment-only
# brokerages. Account filters keep Link to the account types the dashboard
# understands (see NetWorthBreakdown).
module PlaidLink
  KINDS = %w[ bank investment ].freeze
  TRANSACTION_HISTORY_DAYS = 90

  def self.create_token(user:, kind:)
    request =
      case kind
      in "bank"
        Plaid::LinkTokenCreateRequest.new(
          **common_options(user),
          products: [ "transactions" ],
          transactions: Plaid::LinkTokenTransactions.new(days_requested: TRANSACTION_HISTORY_DAYS),
          account_filters: Plaid::LinkTokenAccountFilters.new(
            depository: Plaid::DepositoryFilter.new(account_subtypes: [ "all" ]),
            credit: Plaid::CreditFilter.new(account_subtypes: [ "credit card" ])
          )
        )
      in "investment"
        Plaid::LinkTokenCreateRequest.new(
          **common_options(user),
          products: [ "investments" ],
          account_filters: Plaid::LinkTokenAccountFilters.new(
            investment: Plaid::InvestmentFilter.new(account_subtypes: [ "all" ])
          )
        )
      end

    PlaidClient.api.link_token_create(request).link_token
  end

  def self.common_options(user)
    {
      user: Plaid::LinkTokenCreateRequestUser.new(client_user_id: user.id),
      client_name: "Financial Tracker",
      language: "en",
      country_codes: [ "US" ]
    }
  end
  private_class_method :common_options
end
