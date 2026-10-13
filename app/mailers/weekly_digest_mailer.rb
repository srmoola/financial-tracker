class WeeklyDigestMailer < ApplicationMailer
  helper :budgets

  # Last week's summary. Mail clients' own unsubscribe buttons turn it off in
  # one click (RFC 8058), as does the link in the email.
  def summary(user)
    @user = user
    @digest = WeeklyDigest.new(user)
    @unsubscribe_url = weekly_email_url(token: user.generate_token_for(:weekly_digest))
    headers["List-Unsubscribe"] = "<#{@unsubscribe_url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"

    mail subject: "Your week: #{ActiveSupport::NumberHelper.number_to_currency(@digest.spent)} in new spending", to: user.email_address
  end
end
