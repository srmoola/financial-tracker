# A transaction that doesn't count toward one budget.
class BudgetExclusion < ApplicationRecord
  belongs_to :budget
  belongs_to :purchase, class_name: "Transaction", foreign_key: :transaction_id
end
