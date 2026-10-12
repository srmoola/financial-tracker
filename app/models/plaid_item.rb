# One login/connection to a financial institution through Plaid.
class PlaidItem < ApplicationRecord
  # The Plaid account types the dashboard groups (see NetWorthBreakdown).
  # Link's account filters only offer these, so others are skipped defensively.
  SUPPORTED_ACCOUNT_TYPES = %w[ depository credit investment ].freeze
  # Plaid errors meaning the user hasn't allowed Liabilities (statement dates) for this connection yet.
  STATEMENT_DATES_CONSENT_ERRORS = %w[ ADDITIONAL_CONSENT_REQUIRED PRODUCT_NOT_ENABLED PRODUCTS_NOT_SUPPORTED ].freeze

  belongs_to :user
  has_many :accounts, dependent: :destroy

  encrypts :access_token

  validates :item_id, presence: true, uniqueness: true
  validates :access_token, presence: true

  # Exchanges the public token from a successful Plaid Link for a permanent
  # access token, saves the Item and pulls in its accounts and balances.
  # Transactions follow shortly in a background sync.
  def self.connect!(user:, public_token:)
    exchange = PlaidClient.api.item_public_token_exchange(Plaid::ItemPublicTokenExchangeRequest.new(public_token:))
    user.plaid_items.create!(item_id: exchange.item_id, access_token: exchange.access_token).tap do |plaid_item|
      plaid_item.sync_balances!
      # Plaid needs a moment to gather transactions for a new connection.
      SyncPlaidItemJob.set(wait: 1.minute).perform_later(plaid_item)
    end
  end

  # Balances for every account, then transactions for credit cards (the only
  # accounts we import transactions for, for now).
  def sync!
    sync_balances!
    sync_statement_dates! unless statement_dates_status.in?(%w[ needs_consent unsupported ])
    accounts.credit_cards.find_each(&:sync_transactions!)
  end

  # Saves each credit card's last statement date from Plaid Liabilities, so
  # "This month" can match the card's statement. Connections made before we
  # asked for Liabilities may need the user's consent first (Link update mode);
  # `after_consent` is true right after they've given it.
  def sync_statement_dates!(after_consent: false)
    cards = accounts.credit_cards.to_a
    return if cards.empty?

    response = PlaidClient.api.liabilities_get(Plaid::LiabilitiesGetRequest.new(
      access_token:, options: Plaid::LiabilitiesGetRequestOptions.new(account_ids: cards.map(&:plaid_account_id))
    ))
    statement_dates = Array(response.liabilities&.credit).to_h { |liability| [ liability.account_id, liability.last_statement_issue_date ] }

    transaction do
      cards.each do |card|
        card.update!(last_statement_issue_date: statement_dates[card.plaid_account_id]) if statement_dates.key?(card.plaid_account_id)
      end
      update!(statement_dates_status: "available")
    end
  rescue Plaid::ApiError => error
    code = PlaidClient.error_code(error)
    if code == "NO_LIABILITY_ACCOUNTS"
      update!(statement_dates_status: "unsupported")
    elsif STATEMENT_DATES_CONSENT_ERRORS.include?(code)
      update!(statement_dates_status: after_consent ? "unsupported" : "needs_consent")
    else
      raise
    end
  end

  # Stops Plaid from accessing this bank (/item/remove), then deletes the
  # connection along with its accounts, transactions and balance history.
  def disconnect!
    begin
      PlaidClient.api.item_remove(Plaid::ItemRemoveRequest.new(access_token:))
    rescue Plaid::ApiError => error
      raise unless PlaidClient.error_code(error) == "ITEM_NOT_FOUND" # already removed at Plaid
    end

    destroy!
  end

  # Fetches accounts and their (cached, free) balances from Plaid, updates
  # them, and records the day's balance snapshot for net worth history.
  def sync_balances!(today: Date.current)
    response = PlaidClient.api.accounts_get(Plaid::AccountsGetRequest.new(access_token:))
    synced_at = Time.current

    transaction do
      update!(institution_id: response.item.institution_id, institution_name: response.item.institution_name, last_synced_at: synced_at)

      response.accounts.each do |plaid_account|
        next unless SUPPORTED_ACCOUNT_TYPES.include?(plaid_account.type)

        account = accounts.find_or_initialize_by(plaid_account_id: plaid_account.account_id)
        account.update!(
          name: plaid_account.name,
          mask: plaid_account.mask,
          account_type: plaid_account.type,
          subtype: plaid_account.subtype,
          currency_code: plaid_account.balances.iso_currency_code,
          current_balance: plaid_account.balances.current,
          available_balance: plaid_account.balances.available,
          credit_limit: plaid_account.balances.limit,
          last_synced_at: synced_at
        )
        account.record_balance_snapshot(on: today)
      end
    end
  end
end
