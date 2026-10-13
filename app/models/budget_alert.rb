# An alert email a budget has sent: reaching `threshold` percent in the period starting `period_start`.
class BudgetAlert < ApplicationRecord
  belongs_to :budget
end
