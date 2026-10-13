require "rails_helper"

RSpec.describe "Turning the weekly email on and off", type: :request do
  fixtures :users

  let(:token) { users(:one).generate_token_for(:weekly_digest) }

  it "turns it off from the email's link without logging in, and back on" do
    get weekly_email_path(token:)
    expect(response.body).to include("Weekly email", "one@example.com", "It's on", "Turn off weekly emails")

    patch weekly_email_path, params: { token:, enabled: "0" }
    expect(response).to redirect_to(weekly_email_path(token:))
    expect(users(:one).reload.weekly_digest).to be(false)

    patch weekly_email_path, params: { token:, enabled: "1" }
    expect(users(:one).reload.weekly_digest).to be(true)
  end

  it "turns it off in one click from a mail client" do
    post weekly_email_path(token:), params: { "List-Unsubscribe" => "One-Click" }

    expect(response).to have_http_status(:ok)
    expect(users(:one).reload.weekly_digest).to be(false)
  end

  it "rejects a bad link" do
    get weekly_email_path(token: "nope")
    expect(response).to have_http_status(:not_found)

    post weekly_email_path(token: "nope")
    expect(response).to have_http_status(:not_found)
  end

  it "can be turned off and on from the Settings page" do
    sign_in_as users(:one)

    get settings_path
    expect(response.body).to include("Weekly summary", "Turn off")

    patch weekly_email_path, params: { enabled: "0" }
    expect(response).to redirect_to(settings_path)
    expect(users(:one).reload.weekly_digest).to be(false)
    follow_redirect!
    expect(response.body).to include("You won&#39;t get weekly emails anymore.", "Turn on")
  end
end
