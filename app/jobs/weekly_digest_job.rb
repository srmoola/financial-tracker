# Every Monday (config/recurring.yml): emails each user who wants it a
# summary of last week (see WeeklyDigest).
class WeeklyDigestJob < ApplicationJob
  queue_as :default

  def perform
    User.where(weekly_digest: true).where.not(email_verified_at: nil).find_each do |user|
      WeeklyDigestMailer.summary(user).deliver_later if WeeklyDigest.new(user).worth_sending?
    end
  end
end
