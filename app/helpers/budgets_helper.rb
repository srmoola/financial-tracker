module BudgetsHelper
  STATES = {
    on_track: { label: "On track", badge: "badge-success", bar: "bg-base-content" },
    over_pace: { label: "Over pace", badge: "badge-warning", bar: "bg-warning" },
    over: { label: "Over budget", badge: "badge-error", bar: "bg-error" }
  }.freeze

  def budget_state(status) = STATES.fetch(status.state)

  # "this week" or "this statement month".
  def budget_period_phrase(budget) = budget.weekly? ? "this week" : "this statement month"

  # e.g. "Resets Mon, Oct 19".
  def budget_resets_on(status) = "Resets #{status.resets_on.strftime("%a, %b %-d")}"

  # The categories and merchants a budget counts, e.g. ["Food & drink", "Amazon"].
  def budget_includes(budget)
    budget.categories.map { |category| SpendingBreakdown.label_for(category) } + budget.merchants
  end
end
