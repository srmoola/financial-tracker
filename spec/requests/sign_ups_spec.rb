require "rails_helper"

RSpec.describe "Sign ups", type: :request do
  fixtures :users

  it "renders the sign up page" do
    get sign_up_path
    expect(response).to have_http_status(:success)
  end

  it "redirects when already signed in" do
    sign_in_as users(:one)
    get sign_up_path
    expect(response).to redirect_to(root_path)
  end

  it "creates a user and signs them in" do
    expect {
      post sign_up_path, params: { user: { email_address: "new@example.com", password: "password123", password_confirmation: "password123" } }
    }.to change(User, :count).by(1)

    expect(response).to redirect_to(root_path)
    expect(cookies[:session_id]).to be_present
  end

  it "rejects a mismatched password confirmation" do
    expect {
      post sign_up_path, params: { user: { email_address: "new@example.com", password: "password123", password_confirmation: "different" } }
    }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "rejects an email address that is already taken" do
    expect {
      post sign_up_path, params: { user: { email_address: users(:one).email_address.upcase, password: "password123", password_confirmation: "password123" } }
    }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "rejects a password shorter than 8 characters" do
    expect {
      post sign_up_path, params: { user: { email_address: "new@example.com", password: "short", password_confirmation: "short" } }
    }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
  end
end
