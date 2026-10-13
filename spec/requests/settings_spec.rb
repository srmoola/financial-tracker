require "rails_helper"

RSpec.describe "Settings", type: :request do
  fixtures :users

  it "requires login" do
    get settings_path

    expect(response).to redirect_to(new_session_path)
  end

  it "shows the profile and the weekly email setting, which is no longer on Accounts" do
    sign_in_as users(:one)

    get settings_path
    expect(response.body).to include("Settings", "Jane Doe", "one@example.com", "Upload a photo", "Weekly summary")
    expect(response.body).not_to include("Change photo", "Remove")

    get accounts_path
    expect(response.body).to include('href="/settings"')
    expect(response.body).not_to include("Weekly summary")
  end
end
