# One login/connection to a financial institution through Plaid.
class PlaidItem < ApplicationRecord
  # The Plaid account types the dashboard groups (see NetWorthBreakdown).
  # Link's account filters only offer these, so others are skipped defensively.
  SUPPORTED_ACCOUNT_TYPES = %w[ depository credit investment ].freeze

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
    accounts.credit_cards.find_each(&:sync_transactions!)
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
