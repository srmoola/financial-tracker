module DonutChartHelper
  # Categorical slice colors from Plaid's palette, in ring order. Checked with a
  # color-blind (CVD) palette validator so every pair of neighboring slices,
  # including last -> first, stays distinguishable. Don't cycle these: more slices
  # than colors should be folded into an "Other" slice.
  DONUT_COLORS = %w[#0a85ea #f44e66 #7646ec #ba7d17 #1fa077].freeze

  Segment = Data.define(:color, :share, :dasharray, :dashoffset)

  # Splits a circle of the given radius into one stroke-dash segment per value,
  # leaving a small gap of surface between neighbors.
  def donut_segments(values, radius:, gap: 2)
    circumference = 2 * Math::PI * radius
    total = values.sum.to_f
    start = 0.0

    values.each_with_index.map do |value, index|
      length = value / total * circumference
      dash = [ length - gap, 0.5 ].max
      segment = Segment.new(
        color: DONUT_COLORS.fetch(index),
        share: value / total,
        dasharray: "#{dash.round(3)} #{(circumference - dash).round(3)}",
        dashoffset: (-start).round(3)
      )
      start += length
      segment
    end
  end
end
