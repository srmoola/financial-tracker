class ApplicationMailer < ActionMailer::Base
  # MAIL_FROM, e.g. "Financial Tracker <app@example.com>"; otherwise the SMTP login.
  default from: ENV["MAIL_FROM"].presence || ENV["SMTP_USERNAME"].presence || "from@example.com"
  layout "mailer"
end
