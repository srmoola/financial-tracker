# Link tokens for opening Plaid Link. Banks/credit cards and investment accounts
# are linked separately: Plaid only lists institutions that support every
# requested product, so asking for Transactions would hide investment-only
# brokerages. Account filters keep Link to the account types the dashboard
# understands (see NetWorthBreakdown).
module PlaidLink
  KINDS = %w[ bank investment ].freeze
  TRANSACTION_HISTORY_DAYS = 730 # Plaid's maximum; it can't be raised for a connection later

  def self.create_token(user:, kind:)
    request =
      case kind
      in "bank"
        Plaid::LinkTokenCreateRequest.new(
          **common_options(user),
          products: [ "transactions" ],
          optional_products: [ "liabilities" ], # statement dates, where the bank supports them
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

  # Link update mode for an existing connection, asking the user to also allow
  # Liabilities so we can read their credit card statement dates. Reuses the
  # connection, so it doesn't count as a new one.
  def self.create_statement_dates_token(plaid_item)
    request = Plaid::LinkTokenCreateRequest.new(
      **common_options(plaid_item.user),
      access_token: plaid_item.access_token,
      additional_consented_products: [ "liabilities" ]
    )
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
