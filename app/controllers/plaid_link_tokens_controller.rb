# Creates a Plaid Link token for the kind of account being connected.
class PlaidLinkTokensController < ApplicationController
  def create
    kind = params.expect(:kind)
    return render json: { error: "Unknown account kind." }, status: :unprocessable_content unless PlaidLink::KINDS.include?(kind)

    render json: { link_token: PlaidLink.create_token(user: Current.user, kind:) }
  rescue Plaid::ApiError => error
    Rails.logger.error("Plaid link token failed: #{PlaidClient.error_code(error)}")
    render json: { error: "Couldn't start connecting to Plaid. Please try again." }, status: :bad_gateway
  end
end
