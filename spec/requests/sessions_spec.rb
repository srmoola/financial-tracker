require "rails_helper"

RSpec.describe "Sessions", type: :request do
  fixtures :users

  let(:user) { users(:one) }

  it "renders the sign in page" do
    get new_session_path
    expect(response).to have_http_status(:success)
  end

  it "signs in with valid credentials" do
    post session_path, params: { email_address: user.email_address, password: "password" }

    expect(response).to redirect_to(root_path)
    expect(cookies[:session_id]).to be_present
  end

  it "rejects invalid credentials" do
    post session_path, params: { email_address: user.email_address, password: "wrong" }

    expect(response).to redirect_to(new_session_path)
    expect(cookies[:session_id]).to be_nil
  end

  it "signs out" do
    sign_in_as(user)

    delete session_path

    expect(response).to redirect_to(new_session_path)
    expect(cookies[:session_id]).to be_empty
  end
end
