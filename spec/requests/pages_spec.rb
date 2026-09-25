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
    expect(response.body).to include("Welcome back, Jane", "Jane Doe", "JD", "Log out")
    expect(response.body).not_to include("See all your money in")
  end
end
