require "rails_helper"

RSpec.describe BudgetsHelper, type: :helper do
  it "compares a week's spending with the week before" do
    expect(helper.weekly_change(120, 80)).to eq("up $40.00 from the week before")
    expect(helper.weekly_change(50, 80)).to eq("down $30.00 from the week before")
    expect(helper.weekly_change(80, 80)).to eq("the same as the week before")
    expect(helper.weekly_change(80, 0)).to eq("with none the week before")
  end
end
