require "rails_helper"

RSpec.describe PlaidItem, type: :model do
  fixtures :users

  def create_item(**attributes)
    users(:one).plaid_items.create!(item_id: "item-1", access_token: "access-sandbox-123", **attributes)
  end

  it "encrypts the access token in the database" do
    item = create_item

    raw = PlaidItem.connection.select_value("SELECT access_token FROM plaid_items WHERE id = #{PlaidItem.connection.quote(item.id)}")
    expect(raw).not_to include("access-sandbox-123")
    expect(item.reload.access_token).to eq("access-sandbox-123")
  end

  it "uses a UUID primary key" do
    expect(create_item.id).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
  end

  it "requires a unique Plaid item_id and an access token" do
    create_item

    duplicate = users(:two).plaid_items.build(item_id: "item-1", access_token: "other")
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:item_id]).to include("has already been taken")

    missing_token = users(:one).plaid_items.build(item_id: "item-2")
    expect(missing_token).not_to be_valid
    expect(missing_token.errors[:access_token]).to include("can't be blank")
  end

  it "deletes its accounts and their transactions when the user is deleted" do
    account = create_item.accounts.create!(plaid_account_id: "acc-1", name: "Checking", account_type: "depository")
    account.transactions.create!(plaid_transaction_id: "txn-1", amount: 12.5, date: Date.current)

    expect { users(:one).destroy }
      .to change(PlaidItem, :count).by(-1)
      .and change(Account, :count).by(-1)
      .and change(Transaction, :count).by(-1)
  end
end
