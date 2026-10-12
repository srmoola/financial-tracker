require "rails_helper"

RSpec.describe "App sections", type: :request do
  fixtures :users

  %w[ transactions budgets subscriptions taxes ].each do |section|
    it "shows a placeholder for #{section} when logged in" do
      sign_in_as users(:one)

      get "/#{section}"

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Coming soon")
    end

    it "requires login for #{section}" do
      get "/#{section}"

      expect(response).to redirect_to(new_session_path)
    end
  end
end
