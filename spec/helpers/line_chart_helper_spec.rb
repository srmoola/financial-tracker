require "rails_helper"

RSpec.describe LineChartHelper, type: :helper do
  let(:dates) { (Date.new(2026, 1, 1)..Date.new(2026, 3, 31)).to_a }

  def series(key, values) = LineChartHelper::Series.new(key:, label: key.to_s.titleize, color: "#000000", values:)
  def chart_for(*series_list) = helper.line_chart(dates, series_list, tooltip_rows: dates.map { [ [ "Total", "$1", nil ] ] })

  it "uses round y-axis ticks that cover every series" do
    chart = chart_for(series(:a, dates.each_index.map { |index| 81_200 + index * 100 })) # 81,200 .. 90,100

    expect(chart.y_ticks.map(&:label)).to eq(%w[ $80K $82.5K $85K $87.5K $90K $92.5K ])
    expect(chart.y_ticks.first.position).to eq(100.0)
    expect(chart.y_ticks.last.position).to eq(0.0)
  end

  it "labels a zero tick as $0" do
    chart = chart_for(series(:low, dates.map { 0 }), series(:high, dates.map { 50_000 }))

    expect(chart.y_ticks.first.label).to eq("$0")
  end

  it "gives each series its own line, and each date a hover entry with a y position per series" do
    chart = chart_for(series(:low, dates.map { 0 }), series(:high, dates.map { 100 }))

    expect(chart.lines.map(&:key)).to eq([ :low, :high ])
    expect(chart.lines.map(&:end_y)).to eq([ 100.0, 0.0 ])
    expect(chart.hover.first).to eq([ 0.0, "Jan 1, 2026", [ 100.0, 0.0 ], [ [ "Total", "$1", nil ] ] ])
    expect(chart.hover.last.first).to eq(100.0)
  end

  it "labels the first of each month, skipping one too close to the edge" do
    expect(chart_for(series(:a, dates.map { 1 })).x_ticks.map(&:label)).to eq(%w[ Feb Mar ])
  end

  context "for a week or less" do
    let(:dates) { (Date.new(2026, 10, 7)..Date.new(2026, 10, 13)).to_a }

    it "labels every day" do
      expect(chart_for(series(:a, dates.map { 1 })).x_ticks.map(&:label)).to eq([ "Wed 7", "Thu 8", "Fri 9", "Sat 10", "Sun 11", "Mon 12", "Tue 13" ])
    end
  end

  it "spreads end labels apart when lines end close together" do
    lines = [ 50.0, 52.0, 10.0 ].map { |end_y| LineChartHelper::Line.new(key: end_y, label: "", color: "", points: "", end_y:) }

    expect(helper.end_label_positions(lines).map(&:last)).to eq([ 10.0, 50.0, 59.0 ])
  end

  it "moves end labels back up when they'd run past the bottom of the plot" do
    lines = [ 96.0, 98.0, 100.0 ].map { |end_y| LineChartHelper::Line.new(key: end_y, label: "", color: "", points: "", end_y:) }

    expect(helper.end_label_positions(lines).map(&:last)).to eq([ 82.0, 91.0, 100.0 ])
  end
end
