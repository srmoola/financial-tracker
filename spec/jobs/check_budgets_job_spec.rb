require "rails_helper"

RSpec.describe CheckBudgetsJob, type: :job do
  fixtures :users

  it "checks every budget of the user for alerts" do
    budgets = [ instance_double(Budget), instance_double(Budget) ]
    budgets.each { |budget| expect(budget).to receive(:send_alerts!) }
    allow(users(:one)).to receive(:budgets).and_return(budgets)

    CheckBudgetsJob.perform_now(users(:one))
  end

  it "runs after a connection syncs" do
    plaid_item = users(:one).plaid_items.create!(item_id: "item-1", access_token: "token")
    allow(plaid_item).to receive(:sync!)

    expect { SyncPlaidItemJob.perform_now(plaid_item) }.to have_enqueued_job(CheckBudgetsJob).with(users(:one))
  end
end
