module BudgetsHelper
  STATES = {
    on_track: { label: "On track", badge: "badge-success", bar: "bg-base-content" },
    over_pace: { label: "Over pace", badge: "badge-warning", bar: "bg-warning" },
    over: { label: "Over budget", badge: "badge-error", bar: "bg-error" }
  }.freeze

  def budget_state(status) = STATES.fetch(status.state)

  # How this week's spending compares to last week's, e.g. "up $80.00 from the week before".
  def weekly_change(spent, before)
    return "with none the week before" if before.zero?
    return "the same as the week before" if spent == before

    "#{spent > before ? "up" : "down"} #{number_to_currency((spent - before).abs)} from the week before"
  end

  # e.g. "Resets Mon, Oct 19".
  def budget_resets_on(status) = "Resets #{status.resets_on.strftime("%a, %b %-d")}"

  # The categories and merchants a budget counts, e.g. ["Food & drink", "Amazon"].
  def budget_includes(budget)
    budget.categories.map { |category| SpendingBreakdown.label_for(category) } + budget.merchants
  end
end
