require "rails_helper"

RSpec.describe SyncPlaidItemJob, type: :job do
  fixtures :users

  let(:plaid_item) { users(:one).plaid_items.create!(item_id: "item-1", access_token: "token-1") }

  it "records a daily sync that worked" do
    allow(plaid_item).to receive(:sync!)

    SyncPlaidItemJob.perform_now(plaid_item, daily: true)

    expect(plaid_item.daily_syncs.sole).to have_attributes(succeeded: true, error: nil)
  end

  it "records why a daily sync failed, and still fails the job" do
    error = Plaid::ApiError.new(response_body: { error_code: "ITEM_LOGIN_REQUIRED" }.to_json)
    allow(plaid_item).to receive(:sync!).and_raise(error)

    expect { SyncPlaidItemJob.perform_now(plaid_item, daily: true) }.to raise_error(Plaid::ApiError)
    expect(plaid_item.daily_syncs.sole).to have_attributes(succeeded: false, error: "ITEM_LOGIN_REQUIRED")
  end

  it "doesn't record other syncs (e.g. right after connecting)" do
    allow(plaid_item).to receive(:sync!)

    SyncPlaidItemJob.perform_now(plaid_item)

    expect(plaid_item.daily_syncs).to be_empty
  end
end
