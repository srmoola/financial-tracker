module DonutChartHelper
  # One color per net worth category, from Plaid's palette. Checked with a
  # color-blind (CVD) palette validator: every pair stays distinguishable, which
  # matters because in a 3-slice ring each slice touches both others.
  CATEGORY_COLORS = { checking: "#0a85ea", savings: "#ba7d17", investments: "#1fa077" }.freeze

  # Spending donut colors by number of named slices, each ordered so every pair
  # of touching slices (including last -> first) passes the same color-blind
  # check. "Other" is always neutral gray.
  SPENDING_COLORS = {
    1 => %w[ #0a85ea ],
    2 => %w[ #0a85ea #ba7d17 ],
    3 => %w[ #0a85ea #ba7d17 #1fa077 ],
    4 => %w[ #0a85ea #ba7d17 #7646ec #1fa077 ],
    5 => %w[ #0a85ea #f44e66 #7646ec #ba7d17 #1fa077 ]
  }.freeze
  OTHER_COLOR = "#949494"

  Segment = Data.define(:color, :share, :dasharray, :dashoffset)

  # Colors for spending categories, in order; "Other" (if present) last.
  def spending_colors(categories)
    named = categories.count { |category| category.key != :other }
    colors = named.zero? ? [] : SPENDING_COLORS.fetch(named).dup
    categories.map { |category| category.key == :other ? OTHER_COLOR : colors.shift }
  end

  # Splits a circle of the given radius into one stroke-dash segment per value,
  # leaving a small gap of surface between neighbors. `colors` pairs with `values`.
  def donut_segments(values, colors:, radius:, gap: 2)
    circumference = 2 * Math::PI * radius
    total = values.sum.to_f
    start = 0.0

    values.each_with_index.map do |value, index|
      length = value / total * circumference
      dash = [ length - gap, 0.5 ].max
      segment = Segment.new(
        color: colors.fetch(index),
        share: value / total,
        dasharray: "#{dash.round(3)} #{(circumference - dash).round(3)}",
        dashoffset: (-start).round(3)
      )
      start += length
      segment
    end
  end
end
