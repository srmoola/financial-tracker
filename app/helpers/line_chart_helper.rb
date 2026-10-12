module LineChartHelper
  Series = Data.define(:key, :label, :color, :values)
  Line = Data.define(:key, :label, :color, :points, :end_y)
  LineChart = Data.define(:lines, :y_ticks, :x_ticks, :hover)
  Tick = Data.define(:label, :position)

  # Lays out a line chart (one or more series on one shared y-axis) in percentages
  # of the plot area, so the SVG lines can stretch to any width while the HTML
  # labels stay crisp.
  #   lines   - per series: SVG polyline points in a 0..100 viewBox, and where it ends
  #   y_ticks - round values with their distance from the top (%)
  #   x_ticks - dates with their distance from the left (%)
  #   hover   - per date: [x%, date label, [y% per series], tooltip rows]
  # `hover_labels` and `x_labels` ([[index, label], ...]) replace the default
  # date-based labels, e.g. for points that each stand for a statement period.
  def line_chart(dates, series, tooltip_rows:, hover_labels: nil, x_labels: nil)
    values = series.flat_map(&:values)
    step = nice_step(values.max - values.min)
    low = (values.min / step).floor * step
    high = (values.max / step).ceil * step
    high += step if high == low

    x = ->(index) { dates.size == 1 ? 50.0 : (index * 100.0 / (dates.size - 1)).round(3) }
    y = ->(value) { ((high - value) * 100.0 / (high - low)).round(3) }

    LineChart.new(
      lines: series.map do |line|
        Line.new(key: line.key, label: line.label, color: line.color, end_y: y.(line.values.last),
          points: line.values.each_with_index.map { |value, index| "#{x.(index)},#{y.(value)}" }.join(" "))
      end,
      y_ticks: low.step(high, step).map { |value| Tick.new(label: compact_currency(value, step), position: y.(value)) },
      x_ticks: (x_labels || date_ticks(dates)).map { |index, label| Tick.new(label:, position: x.(index)) },
      hover: dates.each_with_index.map do |date, index|
        [ x.(index), hover_labels ? hover_labels[index] : date.strftime("%b %-d, %Y"), series.map { |line| y.(line.values[index]) }, tooltip_rows[index] ]
      end
    )
  end

  # Where to put each line's end label (% from the top), nudged apart so labels
  # for lines that end close together don't overlap, and kept within the plot.
  def end_label_positions(lines, min_gap: 9)
    sorted = lines.sort_by(&:end_y)
    positions = sorted.map(&:end_y)
    # Push labels down to make room, then back up if the last ones ran past the bottom.
    (1...positions.size).each { |index| positions[index] = [ positions[index], positions[index - 1] + min_gap ].max }
    positions[-1] = [ positions[-1], 100 ].min if positions.any?
    (positions.size - 2).downto(0) { |index| positions[index] = [ positions[index], positions[index + 1] - min_gap ].min }
    sorted.zip(positions)
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
      return number_to_currency(value, precision: 0) if step < 1_000 || value.zero?

      "$#{number_with_precision(value / 1_000.0, precision: 1, delimiter: ",", strip_insignificant_zeros: true)}K"
    end
end
