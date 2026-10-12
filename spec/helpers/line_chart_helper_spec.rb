require "rails_helper"

RSpec.describe LineChartHelper, type: :helper do
  let(:dates) { (Date.new(2026, 1, 1)..Date.new(2026, 3, 31)).to_a }

  it "uses round y-axis ticks that cover the data" do
    values = dates.each_index.map { |index| 81_200 + index * 100 } # 81,200 .. 90,100

    chart = helper.line_chart(dates, values)

    expect(chart.y_ticks.map(&:label)).to eq(%w[ $80K $82.5K $85K $87.5K $90K $92.5K ])
    expect(chart.y_ticks.first.position).to eq(100.0)
    expect(chart.y_ticks.last.position).to eq(0.0)
  end

  it "places points left to right across the plot, with hover labels" do
    chart = helper.line_chart(dates, dates.map { 1_000 })

    expect(chart.points.first).to start_with(0.0)
    expect(chart.points.last).to start_with(100.0)
    expect(chart.points.first.last(2)).to eq([ "Jan 1, 2026", "$1,000.00" ])
  end

  it "labels the first of each month, skipping one too close to the edge" do
    chart = helper.line_chart(dates, dates.map { 1 })

    expect(chart.x_ticks.map(&:label)).to eq(%w[ Feb Mar ])
  end
end
