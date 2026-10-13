# One part of a split purchase: its share of the amount, in a category.
class TransactionSplit < ApplicationRecord
  belongs_to :purchase, class_name: "Transaction", foreign_key: :transaction_id
end
