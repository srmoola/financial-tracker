# Confirms a new account's email address with the 6-digit code emailed at sign-up.
class EmailVerificationsController < ApplicationController
  layout "auth"
  allow_unverified_email
  before_action -> { redirect_to root_path if Current.user.email_verified? }
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to email_verification_path, alert: "Try again later." }

  def show
  end

  def create
    case Current.user.verify_email_with(params[:code])
    when :verified
      redirect_to onboarding_path, notice: "Your email is confirmed."
    when :incorrect
      flash.now[:alert] = "That code isn't right. Check the email and try again."
      render :show, status: :unprocessable_content
    when :expired
      flash.now[:alert] = "That code has expired. Send yourself a new one below."
      render :show, status: :unprocessable_content
    when :too_many_attempts
      flash.now[:alert] = "Too many wrong codes. Send yourself a new one below."
      render :show, status: :unprocessable_content
    end
  end

  def resend
    if Current.user.can_resend_email_verification_code?
      EmailVerificationsMailer.code(Current.user, Current.user.generate_email_verification_code!).deliver_later
      redirect_to email_verification_path, notice: "We sent a new code to #{Current.user.email_address}."
    else
      redirect_to email_verification_path, alert: "We just sent a code. Wait a minute before asking for another."
    end
  end
end
