require "rails_helper"

RSpec.describe DonutChartHelper, type: :helper do
  it "splits the circle into one segment per value, in order" do
    segments = helper.donut_segments([ 30, 10 ], colors: %w[ #111111 #222222 ], radius: 80, gap: 2)
    circumference = 2 * Math::PI * 80

    expect(segments.map(&:share)).to eq([ 0.75, 0.25 ])
    expect(segments.map(&:color)).to eq(%w[ #111111 #222222 ])
    expect(segments.map(&:dashoffset)).to eq([ 0.0, -(0.75 * circumference).round(3) ])

    dash, rest = segments.first.dasharray.split.map(&:to_f)
    expect(dash).to be_within(0.001).of(0.75 * circumference - 2)
    expect(dash + rest).to be_within(0.001).of(circumference)
  end

  it "requires a color for every value" do
    expect { helper.donut_segments([ 1, 2 ], colors: %w[ #111111 ], radius: 80) }.to raise_error(IndexError)
  end

  it "colors spending slices from the palette for that many slices, with Other in gray" do
    category = ->(key) { SpendingBreakdown::Category.new(key:, label: key.to_s, total: 1, count: 1) }

    expect(helper.spending_colors([ category.("A"), category.("B") ])).to eq(DonutChartHelper::SPENDING_COLORS[2])
    expect(helper.spending_colors([ category.("A"), category.("B"), category.("C"), category.(:other) ]))
      .to eq([ *DonutChartHelper::SPENDING_COLORS[3], DonutChartHelper::OTHER_COLOR ])
    expect(helper.spending_colors([])).to eq([])
  end
end
