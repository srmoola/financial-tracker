require "rails_helper"

RSpec.describe "Pages", type: :request do
  fixtures :users

  it "shows the landing page when logged out" do
    get root_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("See all your money in")
    expect(response.body).not_to include("Log out")
  end

  it "shows the dashboard when logged in" do
    sign_in_as users(:one)

    get root_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Jane Doe", "JD", "Log out")
    expect(response.body).not_to include("See all your money in")
  end

  it "shows the net worth chart grouped by category on the dashboard" do
    sign_in_as users(:one)

    get root_path

    expect(response.body).to include("Net worth", "$93,358.70", "Sample data")
    expect(response.body).to include("Checking", "Savings", "Investments", "Credit cards")
    expect(response.body).to include("Joint Checking", "Roth IRA", "Rewards Credit Card", "3 accounts")
    expect(response.body.scan('data-donut-target="segment"').size).to eq(3)
  end
end
