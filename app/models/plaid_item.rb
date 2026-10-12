# One login/connection to a financial institution through Plaid.
class PlaidItem < ApplicationRecord
  belongs_to :user
  has_many :accounts, dependent: :destroy

  encrypts :access_token

  validates :item_id, presence: true, uniqueness: true
  validates :access_token, presence: true
end
