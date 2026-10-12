# An individual account (checking, credit card, brokerage, ...) within a PlaidItem.
class Account < ApplicationRecord
  TRANSACTIONS_PAGE_SIZE = 500 # Plaid's maximum per /transactions/sync call

  belongs_to :plaid_item
  has_many :transactions, dependent: :destroy
  has_many :balance_snapshots, class_name: "AccountBalanceSnapshot", dependent: :destroy

  validates :plaid_account_id, presence: true, uniqueness: true
  validates :name, :account_type, presence: true

  scope :credit_cards, -> { where(account_type: "credit") }

  delegate :institution_name, to: :plaid_item

  # Plaid's current balance; for credit cards, the amount owed.
  def balance = current_balance || 0

  # The first day of this card's current statement period: the day after its
  # last statement (moved forward a month at a time if that date is stale), or
  # the 1st of the month when Plaid hasn't provided a statement date.
  def current_statement_start(today: Date.current)
    return today.beginning_of_month if last_statement_issue_date.nil?

    start = last_statement_issue_date + 1
    start = start.next_month while start.next_month <= today
    start
  end

  # Saves today's balance (replacing an earlier one from the same day).
  def record_balance_snapshot(on:)
    return if current_balance.nil?

    balance_snapshots.find_or_initialize_by(date: on).update!(balance: current_balance)
  end

  # Pulls this account's new, changed and removed transactions from Plaid's
  # /transactions/sync. Filtering by account_id gives each account its own
  # cursor, so we can import transactions for some accounts (credit cards) only.
  def sync_transactions!
    changes = fetch_transaction_changes(transaction_sync_cursor)

    transaction do
      changes[:upserts].each { |plaid_transaction| save_plaid_transaction(plaid_transaction) }
      transactions.where(plaid_transaction_id: changes[:removed]).delete_all
      update!(transaction_sync_cursor: changes[:cursor])
    end
  end

  private
    def fetch_transaction_changes(starting_cursor, attempts: 3)
      cursor = starting_cursor
      upserts = []
      removed = []

      loop do
        response = PlaidClient.api.transactions_sync(Plaid::TransactionsSyncRequest.new(
          access_token: plaid_item.access_token,
          cursor:,
          count: TRANSACTIONS_PAGE_SIZE,
          options: Plaid::TransactionsSyncRequestOptions.new(account_id: plaid_account_id, include_personal_finance_category: true)
        ))
        upserts.concat(response.added, response.modified)
        removed.concat(response.removed.map(&:transaction_id))
        cursor = response.next_cursor
        return { upserts:, removed:, cursor: } unless response.has_more
      end
    rescue Plaid::ApiError => error
      # Plaid's data changed while paging: start over from the cursor we began with.
      raise unless PlaidClient.error_code(error) == "TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION" && attempts > 1

      fetch_transaction_changes(starting_cursor, attempts: attempts - 1)
    end

    def save_plaid_transaction(plaid_transaction)
      transactions.find_or_initialize_by(plaid_transaction_id: plaid_transaction.transaction_id).update!(
        amount: plaid_transaction.amount,
        currency_code: plaid_transaction.iso_currency_code,
        merchant_name: plaid_transaction.merchant_name,
        description: plaid_transaction.name,
        date: plaid_transaction.date,
        datetime: plaid_transaction.datetime,
        pending: plaid_transaction.pending,
        pending_transaction_id: plaid_transaction.pending_transaction_id,
        category: plaid_transaction.personal_finance_category&.primary,
        latitude: plaid_transaction.location&.lat,
        longitude: plaid_transaction.location&.lon,
        payment_channel: plaid_transaction.payment_channel
      )
    end
end
