require "rails_helper"

RSpec.describe WeeklyDigestJob, type: :job do
  fixtures :users

  def connect(user) = user.plaid_items.create!(item_id: "item-#{user.id}", access_token: "token").accounts.create!(plaid_account_id: "acc-#{user.id}", name: "Card", account_type: "credit", subtype: "credit card")

  it "emails everyone who wants it, has confirmed their email and has accounts" do
    connect(users(:one))
    connect(users(:two)).plaid_item.user.update!(weekly_digest: false)
    User.create!(first_name: "No", last_name: "Accounts", email_address: "none@example.com", password: "password123", email_verified_at: Time.current)

    expect { WeeklyDigestJob.perform_now }.to have_enqueued_mail(WeeklyDigestMailer, :summary).with(users(:one)).exactly(:once)
  end

  it "runs every Monday" do
    schedule = YAML.load_file(Rails.root.join("config/recurring.yml"))

    expect(schedule.dig("production", "weekly_digest")).to eq("class" => "WeeklyDigestJob", "schedule" => "every monday at 1pm")
  end
end
