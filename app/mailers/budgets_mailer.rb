class BudgetsMailer < ApplicationMailer
  helper :budgets

  # A budget has reached `threshold` percent (50, 90 or 100) this period.
  def threshold(budget, threshold)
    @budget = budget
    @threshold = threshold
    @status = budget.status
    subject = threshold >= 100 ? "You've reached your #{budget.name} budget" : "You've used #{threshold}% of your #{budget.name} budget"
    mail subject:, to: budget.user.email_address
  end
end
