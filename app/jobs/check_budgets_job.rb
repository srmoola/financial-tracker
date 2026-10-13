# After a sync brings in new transactions: emails the user about any budget
# that has just reached 50%, 90% or 100% (see Budget#send_alerts!).
class CheckBudgetsJob < ApplicationJob
  queue_as :default

  def perform(user)
    user.budgets.each(&:send_alerts!)
  end
end
