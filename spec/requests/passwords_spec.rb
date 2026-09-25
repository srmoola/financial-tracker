require "rails_helper"

RSpec.describe "Passwords", type: :request do
  fixtures :users

  let(:user) { users(:one) }

  it "renders the forgot password page" do
    get new_password_path
    expect(response).to have_http_status(:success)
  end

  it "sends reset instructions to a known user" do
    expect {
      post passwords_path, params: { email_address: user.email_address }
    }.to have_enqueued_mail(PasswordsMailer, :reset).with(user)

    expect(response).to redirect_to(new_session_path)
    expect(flash[:notice]).to include("reset instructions sent")
  end

  it "redirects but sends no mail for an unknown user" do
    expect {
      post passwords_path, params: { email_address: "missing-user@example.com" }
    }.not_to have_enqueued_mail

    expect(response).to redirect_to(new_session_path)
    expect(flash[:notice]).to include("reset instructions sent")
  end

  it "renders the reset page for a valid token" do
    get edit_password_path(user.password_reset_token)
    expect(response).to have_http_status(:success)
  end

  it "redirects for an invalid token" do
    get edit_password_path("invalid token")

    expect(response).to redirect_to(new_password_path)
    expect(flash[:alert]).to include("reset link is invalid")
  end

  it "resets the password" do
    expect {
      put password_path(user.password_reset_token), params: { password: "newpassword", password_confirmation: "newpassword" }
    }.to change { user.reload.password_digest }

    expect(response).to redirect_to(new_session_path)
    expect(flash[:notice]).to eq("Password has been reset.")
  end

  it "does not reset the password when the confirmation doesn't match" do
    token = user.password_reset_token

    expect {
      put password_path(token), params: { password: "password123", password_confirmation: "different" }
    }.not_to change { user.reload.password_digest }

    expect(response).to redirect_to(edit_password_path(token))
    expect(flash[:alert]).to eq("Password confirmation doesn't match Password")
  end
end
