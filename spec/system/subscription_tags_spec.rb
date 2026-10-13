require "rails_helper"

RSpec.describe "Tagging subscriptions", type: :system do
  fixtures :users

  it "adds and removes tags right on a subscription, without opening it" do
    card = users(:one).plaid_items.create!(item_id: "item-1", access_token: "token", institution_name: "Bank")
      .accounts.create!(plaid_account_id: "card-1", name: "Rewards Card", account_type: "credit", subtype: "credit card")
    [ 2, 1, 0 ].each { |back| card.transactions.create!(plaid_transaction_id: "amazon-#{back}", amount: 14.99, date: Date.current << back, merchant_name: "Amazon", category: "GENERAL_MERCHANDISE") }

    visit new_session_path
    fill_in "Email", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_on "Log in"
    expect(page).to have_text("Jane Doe") # logged in
    visit subscriptions_path

    expect(page).to have_css(".badge", text: "New")
    expect(page).to have_no_css("input[placeholder='New tag']") # until + Tag is pressed
    click_on "+ Tag"
    find("input[placeholder='New tag']").send_keys("Prime Video", :enter)

    expect(page).to have_css(".badge", text: "Prime Video")
    find("input[placeholder='New tag']:focus").send_keys("Shared", :enter) # stays open to add another
    expect(page).to have_css(".badge", text: "Shared")

    find("button[aria-label='Remove tag Prime Video']").click
    expect(page).to have_no_css(".badge", text: "Prime Video")
    expect(page).to have_css(".badge", text: "Shared")
    expect(page).to have_no_css("[id$=_details]:not([hidden])") # the card stayed closed

    find("button[aria-label='Details for Amazon']").click
    expect(page).to have_text("Total paid")
    expect(SubscriptionMark.sole.tags).to eq([ "Shared" ])
  end
end
