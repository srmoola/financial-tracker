require "rails_helper"

RSpec.describe "Searching transactions", type: :system do
  fixtures :users

  it "searches once typing stops, updating just the list" do
    card = users(:one).plaid_items.create!(item_id: "item-1", access_token: "token", institution_name: "Bank")
      .accounts.create!(plaid_account_id: "card-1", name: "Rewards Card", account_type: "credit", subtype: "credit card")
    card.transactions.create!(plaid_transaction_id: "coffee", amount: 12, date: Date.current, category: "FOOD_AND_DRINK", merchant_name: "Blue Bottle Coffee")
    card.transactions.create!(plaid_transaction_id: "groceries", amount: 30, date: Date.current, category: "GENERAL_MERCHANDISE", merchant_name: "Whole Foods")

    visit new_session_path
    fill_in "Email", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_on "Log in"
    expect(page).to have_text("Jane Doe") # logged in
    visit transactions_path

    # Mark the donut and count the searches sent.
    page.execute_script(<<~JS)
      document.getElementById("spending-heading").dataset.untouched = "true"
      window.searches = 0
      document.addEventListener("turbo:before-fetch-request", () => window.searches++)
    JS

    find("#transactions-search").send_keys("coffee")

    within("#transactions_list") { expect(page).to have_text("Showing 1–1 of 1").and have_no_text("Whole Foods") }
    expect(page.evaluate_script("window.searches")).to eq(1)
    expect(page).to have_css("#spending-heading[data-untouched]") # the donut wasn't re-rendered
    expect(page.evaluate_script("document.activeElement.id")).to eq("transactions-search")
    expect(page).to have_current_path(/q=coffee/)
  end
end
