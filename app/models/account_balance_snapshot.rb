# An account's balance on a given day. Net worth history is built from these.
class AccountBalanceSnapshot < ApplicationRecord
  belongs_to :account

  delegate :account_type, :subtype, to: :account

  validates :date, presence: true, uniqueness: { scope: :account_id }
  validates :balance, presence: true
end
