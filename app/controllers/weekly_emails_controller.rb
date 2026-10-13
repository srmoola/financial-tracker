# Turns the Monday summary email on or off: from the link in the email (by
# token, no login needed), from mail clients' one-click unsubscribe, or from
# the Settings page.
class WeeklyEmailsController < ApplicationController
  layout "auth"
  allow_unauthenticated_access
  allow_unverified_email
  skip_forgery_protection only: :create # mail clients' one-click unsubscribe (RFC 8058) posts without a CSRF token
  before_action :set_user

  def show
  end

  def update
    enabled = params[:enabled] == "1"
    @user.update!(weekly_digest: enabled)
    notice = enabled ? "You'll get a summary email every Monday." : "You won't get weekly emails anymore."
    redirect_to params[:token].present? ? weekly_email_path(token: params[:token]) : settings_path, notice:, status: :see_other
  end

  # One-click unsubscribe from a mail client.
  def create
    @user.update!(weekly_digest: false)
    head :ok
  end

  private
    def set_user
      @user = params[:token].present? ? User.find_by_token_for(:weekly_digest, params[:token]) : (Current.user if authenticated?)
      head :not_found unless @user
    end
end
