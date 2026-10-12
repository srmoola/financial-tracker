class EmailVerificationsMailer < ApplicationMailer
  # The code that confirms a new account's email address.
  def code(user, code)
    @user = user
    @code = code
    mail subject: "#{code} is your Financial Tracker code", to: user.email_address
  end
end
