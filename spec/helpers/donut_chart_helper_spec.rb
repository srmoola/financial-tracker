require "rails_helper"

RSpec.describe DonutChartHelper, type: :helper do
  it "splits the circle into one segment per value, in order" do
    segments = helper.donut_segments([ 30, 10 ], radius: 80, gap: 2)
    circumference = 2 * Math::PI * 80

    expect(segments.map(&:share)).to eq([ 0.75, 0.25 ])
    expect(segments.map(&:color)).to eq(DonutChartHelper::DONUT_COLORS.first(2))
    expect(segments.map(&:dashoffset)).to eq([ 0.0, -(0.75 * circumference).round(3) ])

    dash, rest = segments.first.dasharray.split.map(&:to_f)
    expect(dash).to be_within(0.001).of(0.75 * circumference - 2)
    expect(dash + rest).to be_within(0.001).of(circumference)
  end

  it "refuses to reuse colors when there are more slices than colors" do
    values = Array.new(DonutChartHelper::DONUT_COLORS.size + 1, 1)

    expect { helper.donut_segments(values, radius: 80) }.to raise_error(IndexError)
  end
end
