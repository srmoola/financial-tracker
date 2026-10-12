require "rails_helper"

# The Mission Control - Jobs dashboard. Outside development it needs the HTTP
# Basic login from credentials (mission_control.http_basic_auth_user/password),
# on top of being logged in to the app.
RSpec.describe "Jobs dashboard", type: :request do
  fixtures :users

  before do
    allow(MissionControl::Jobs).to receive_messages(http_basic_auth_user: "admin", http_basic_auth_password: "correct-password")
    sign_in_as users(:one)
  end

  def basic_auth(password) = { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", password) }

  it "asks for the dashboard login" do
    get "/jobs"
    expect(response).to have_http_status(:unauthorized)

    get "/jobs", headers: basic_auth("wrong-password")
    expect(response).to have_http_status(:unauthorized)
  end

  it "opens with the dashboard login" do
    get "/jobs", headers: basic_auth("correct-password")

    expect(response).to have_http_status(:ok)
  end
end
