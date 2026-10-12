module LineChartHelper
  LineChart = Data.define(:line, :y_ticks, :x_ticks, :points)
  Tick = Data.define(:label, :position)

  # Lays out a single-series line chart in percentages of the plot area, so the
  # SVG line can stretch to any width while the HTML labels stay crisp.
  #   line    - SVG polyline points in a 0..100 viewBox
  #   y_ticks - round values with their distance from the top (%)
  #   x_ticks - dates with their distance from the left (%)
  #   points  - [x%, y%, date label, value label] per point, for the hover layer
  def line_chart(dates, values)
    step = nice_step(values.max - values.min)
    low = (values.min / step).floor * step
    high = (values.max / step).ceil * step
    high += step if high == low

    x = ->(index) { values.size == 1 ? 50.0 : (index * 100.0 / (values.size - 1)).round(3) }
    y = ->(value) { ((high - value) * 100.0 / (high - low)).round(3) }

    LineChart.new(
      line: values.each_with_index.map { |value, index| "#{x.(index)},#{y.(value)}" }.join(" "),
      y_ticks: low.step(high, step).map { |value| Tick.new(label: compact_currency(value, step), position: y.(value)) },
      x_ticks: date_ticks(dates).map { |index, label| Tick.new(label:, position: x.(index)) },
      points: dates.zip(values).each_with_index.map do |(date, value), index|
        [ x.(index), y.(value), date.strftime("%b %-d, %Y"), number_to_currency(value) ]
      end
    )
  end

  private
    # A round step (1, 2, 2.5 or 5 times a power of ten) giving about four gridlines.
    def nice_step(span)
      rough = [ span, 1 ].max / 4.0
      magnitude = 10**Math.log10(rough).floor
      [ 1, 2, 2.5, 5, 10 ].map { |factor| factor * magnitude }.find { |step| step >= rough }
    end

    # Mondays for short ranges, otherwise the first of each month. Skips labels
    # too close to the edges to fit.
    def date_ticks(dates)
      short = dates.size <= 31
      dates.each_with_index.filter_map do |date, index|
        next unless short ? date.monday? : date.day == 1
        next if index < dates.size * 0.03 || index > dates.size * 0.97
        [ index, date.strftime(short ? "%b %-d" : "%b") ]
      end
    end

    def compact_currency(value, step)
      return number_to_currency(value, precision: 0) if step < 1_000

      "$#{number_with_precision(value / 1_000.0, precision: 1, delimiter: ",", strip_insignificant_zeros: true)}K"
    end
end
