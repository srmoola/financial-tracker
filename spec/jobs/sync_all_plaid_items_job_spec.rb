require "rails_helper"

RSpec.describe SyncAllPlaidItemsJob, type: :job do
  fixtures :users

  it "queues a daily sync for every Plaid connection" do
    first = users(:one).plaid_items.create!(item_id: "item-1", access_token: "token-1")
    second = users(:two).plaid_items.create!(item_id: "item-2", access_token: "token-2")

    expect { SyncAllPlaidItemsJob.perform_now }
      .to have_enqueued_job(SyncPlaidItemJob).with(first, daily: true)
      .and have_enqueued_job(SyncPlaidItemJob).with(second, daily: true)
  end

  it "is scheduled to run every day" do
    schedule = YAML.load_file(Rails.root.join("config/recurring.yml"))

    expect(schedule.dig("production", "sync_plaid_balances")).to eq("class" => "SyncAllPlaidItemsJob", "schedule" => "every day at 6am")
  end
end
