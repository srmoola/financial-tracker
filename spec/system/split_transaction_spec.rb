require "rails_helper"

RSpec.describe "Splitting a transaction", type: :system do
  fixtures :users

  it "splits a purchase across categories from the category picker, then removes the split" do
    users(:one).plaid_items.create!(item_id: "item-1", access_token: "token", institution_name: "Bank")
      .accounts.create!(plaid_account_id: "card-1", name: "Rewards Card", account_type: "credit", subtype: "credit card")
      .transactions.create!(plaid_transaction_id: "costco", amount: 180, date: Date.current, category: "GENERAL_MERCHANDISE", merchant_name: "Costco")

    visit new_session_path
    fill_in "Email", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_on "Log in"
    expect(page).to have_text("Jane Doe") # logged in
    visit transactions_path

    find("button[aria-label='Category: Shopping. Change category']").click
    click_on "Split across categories"
    within "dialog[aria-labelledby=split-heading]" do
      parts = all("[data-part]")
      parts.first.find("input").fill_in(with: "120")
      parts.last.find("select").select("Food & drink")
      expect(parts.last.find("input").value).to eq("60.00") # what's left
      click_on "Save split"
    end

    split = "button[aria-label='Split into Shopping $120.00 and Food & drink $60.00. Change split']"
    expect(page).to have_css(split, text: "Split · Shopping, Food & drink")

    find(split).click
    click_on "Remove split"

    expect(page).to have_css("button[aria-label='Category: Shopping. Change category']")
    expect(page).to have_no_css(split)
    expect(Transaction.find_by!(plaid_transaction_id: "costco").splits).to be_empty
  end
end
