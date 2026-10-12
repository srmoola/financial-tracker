module DonutChartHelper
  # One color per net worth category, from Plaid's palette. Checked with a
  # color-blind (CVD) palette validator: every pair stays distinguishable, which
  # matters because in a 3-slice ring each slice touches both others.
  CATEGORY_COLORS = { checking: "#0a85ea", savings: "#ba7d17", investments: "#1fa077" }.freeze

  Segment = Data.define(:color, :share, :dasharray, :dashoffset)

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
