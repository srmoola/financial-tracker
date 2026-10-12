# Saves a connection after Plaid Link succeeds, then sends the user on.
class PlaidItemsController < ApplicationController
  def create
    plaid_item = PlaidItem.connect!(user: Current.user, public_token: params.expect(:public_token))

    flash[:notice] = "Connected #{plaid_item.institution_name.presence || "your account"}."
    render json: { redirect_url: params[:from] == "accounts" ? accounts_path : root_path }
  rescue Plaid::ApiError => error
    Rails.logger.error("Plaid connect failed: #{PlaidClient.error_code(error)}")
    render json: { error: "Couldn't finish connecting your account. Please try again." }, status: :bad_gateway
  end
end
