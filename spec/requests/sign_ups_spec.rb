require "rails_helper"

RSpec.describe "Sign ups", type: :request do
  fixtures :users

  let(:valid_params) do
    { first_name: "Ada", last_name: "Lovelace", email_address: "new@example.com", password: "password123", password_confirmation: "password123" }
  end

  def sign_up(overrides = {})
    post sign_up_path, params: { user: valid_params.merge(overrides) }
  end

  it "renders the sign up page" do
    get sign_up_path
    expect(response).to have_http_status(:success)
  end

  it "redirects when already signed in" do
    sign_in_as users(:one)
    get sign_up_path
    expect(response).to redirect_to(root_path)
  end

  it "creates a user with their name and signs them in" do
    expect { sign_up }.to change(User, :count).by(1)

    expect(response).to redirect_to(root_path)
    expect(cookies[:session_id]).to be_present
    expect(User.last).to have_attributes(first_name: "Ada", last_name: "Lovelace")
  end

  it "rejects a missing first or last name" do
    expect { sign_up(first_name: "", last_name: " ") }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("First name can&#39;t be blank", "Last name can&#39;t be blank")
  end

  it "rejects a mismatched password confirmation" do
    expect { sign_up(password_confirmation: "different") }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "rejects an email address that is already taken" do
    expect { sign_up(email_address: users(:one).email_address.upcase) }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "rejects a password shorter than 8 characters" do
    expect { sign_up(password: "short", password_confirmation: "short") }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
  end
end
