require "rails_helper"

RSpec.describe "Authentication", type: :system do
  fixtures :users

  it "signs up from the landing page, logs out and logs back in" do
    visit root_path
    expect(page).to have_text("See all your money in one place")

    click_on "Get started"
    fill_in "Email", with: "new@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"
    click_on "Sign up"

    expect(page).to have_text("Signed in as new@example.com")

    click_on "Log out"
    expect(page).to have_current_path(new_session_path)

    fill_in "Email", with: "new@example.com"
    fill_in "Password", with: "password123"
    click_on "Log in"

    expect(page).to have_text("Signed in as new@example.com")
  end

  it "shows an error for a wrong password" do
    visit new_session_path
    fill_in "Email", with: users(:one).email_address
    fill_in "Password", with: "wrong"
    click_on "Log in"

    expect(page).to have_text("Try another email address or password.")
    expect(page).to have_current_path(new_session_path)
  end
end
