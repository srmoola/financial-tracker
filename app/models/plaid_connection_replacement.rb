# Moves what's worth keeping from an old Plaid connection to a newer one for
# the same bank (balance history, category edits, notes, statement dates), then
# removes the old connection. Plaid can't extend the
# transaction history of an existing connection, so getting more history means
# linking the bank again; this keeps the balance history and category edits.
class PlaidConnectionReplacement
  Result = Data.define(:accounts_matched, :snapshots_moved, :edits_copied, :edits_unmatched, :unmatched_accounts)

  def initialize(old_item, new_item)
    raise ArgumentError, "Both connections must belong to the same user" unless old_item.user_id == new_item.user_id
    raise ArgumentError, "The new connection must be a different one" if old_item == new_item

    @old_item = old_item
    @new_item = new_item
  end

  def run!
    result = ActiveRecord::Base.transaction { move_data }
    remove_old_item
    result
  end

  private
    def move_data
      snapshots_moved = 0
      edits_copied = 0
      edits_unmatched = 0
      unmatched = []

      @old_item.accounts.each do |old_account|
        new_account = matching_account(old_account)
        next unmatched << old_account.name unless new_account

        # Balance history: keep the new connection's snapshot on days both have one.
        snapshots_moved += old_account.balance_snapshots.where.not(date: new_account.balance_snapshots.select(:date)).update_all(account_id: new_account.id)

        # Category edits and notes: Plaid gives re-fetched transactions new ids, so match on date,
        # amount and merchant, skipping new transactions that already have edits.
        old_account.transactions.where.not(category_override: nil).or(old_account.transactions.where.not(note: nil)).find_each do |old_transaction|
          match = new_account.transactions.find_by(
            category_override: nil, note: nil, date: old_transaction.date, amount: old_transaction.amount,
            merchant_name: old_transaction.merchant_name, description: old_transaction.description
          )
          if match
            match.update!(category_override: old_transaction.category_override, note: old_transaction.note)
            edits_copied += 1
          else
            edits_unmatched += 1
          end
        end

        new_account.update!(last_statement_issue_date: old_account.last_statement_issue_date) if new_account.last_statement_issue_date.nil?
      end

      Result.new(accounts_matched: @old_item.accounts.size - unmatched.size, snapshots_moved:, edits_copied:, edits_unmatched:, unmatched_accounts: unmatched)
    end

    def matching_account(old_account)
      @new_item.accounts.find do |candidate|
        [ candidate.account_type, candidate.subtype ] == [ old_account.account_type, old_account.subtype ] &&
          (old_account.mask.present? ? candidate.mask == old_account.mask : candidate.name == old_account.name)
      end
    end

    def remove_old_item
      begin
        PlaidClient.api.item_remove(Plaid::ItemRemoveRequest.new(access_token: @old_item.access_token))
      rescue Plaid::ApiError => error
        raise unless PlaidClient.error_code(error) == "ITEM_NOT_FOUND" # already gone at Plaid
      end

      @old_item.destroy!
    end
end
