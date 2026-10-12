require "rails_helper"

RSpec.describe DailySync do
  fixtures :users

  let(:now) { Time.utc(2026, 10, 12, 5) } # before today's 6:00 UTC run
  let(:today) { now.to_date }
  let(:bank) { users(:one).plaid_items.create!(item_id: "item-1", access_token: "token-1", institution_name: "Capital One") }
  let(:other_bank) { users(:one).plaid_items.create!(item_id: "item-2", access_token: "token-2", institution_name: "Fidelity") }

  def synced(plaid_item, at, succeeded: true, error: nil)
    plaid_item.daily_syncs.create!(succeeded:, error:, created_at: at)
  end

  def days(at: now) = DailySync.days_for(users(:one), now: at)

  it "has no days before the first daily sync" do
    expect(days).to eq([])
  end

  it "lists each day back to the first sync, newest first: synced, failed, didn't run, or not yet today" do
    synced(bank, Time.utc(2026, 10, 9, 6))
    synced(other_bank, Time.utc(2026, 10, 9, 6))
    synced(bank, Time.utc(2026, 10, 11, 6))
    synced(other_bank, Time.utc(2026, 10, 11, 6), succeeded: false, error: "ITEM_LOGIN_REQUIRED")

    expect(days.map { |day| [ day.date, day.status ] }).to eq([
      [ today, :pending ],
      [ Date.new(2026, 10, 11), :failed ],
      [ Date.new(2026, 10, 10), :missed ],
      [ Date.new(2026, 10, 9), :succeeded ]
    ])
    failed = days.second
    expect(failed).to have_attributes(bank_count: 2, ran_at: Time.utc(2026, 10, 11, 6))
    expect(failed.failures.map { |sync| [ sync.plaid_item.institution_name, sync.error ] }).to eq([ [ "Fidelity", "ITEM_LOGIN_REQUIRED" ] ])
  end

  it "counts today as missed once the run is an hour late" do
    synced(bank, Time.utc(2026, 10, 11, 6))

    expect(days(at: Time.utc(2026, 10, 12, 6, 59)).first.status).to eq(:pending)
    expect(days(at: Time.utc(2026, 10, 12, 7)).first.status).to eq(:missed)
  end

  it "counts a connection by its last attempt that day" do
    synced(bank, Time.utc(2026, 10, 12, 6), succeeded: false, error: "INTERNAL_SERVER_ERROR")
    synced(bank, Time.utc(2026, 10, 12, 7))

    expect(days.first).to have_attributes(status: :succeeded, bank_count: 1)
  end

  it "shows only the user's own connections, for the last 30 days" do
    synced(users(:two).plaid_items.create!(item_id: "item-3", access_token: "token-3"), Time.utc(2026, 10, 12, 6))
    expect(days).to eq([])

    synced(bank, Time.utc(2026, 8, 1, 6))
    expect(days.size).to eq(30)
  end
end
