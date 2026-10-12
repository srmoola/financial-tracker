# Creates a Plaid Link token: for connecting a new account (by kind), or for
# re-opening an existing connection to allow statement dates (update mode).
class PlaidLinkTokensController < ApplicationController
  def create
    render json: { link_token: link_token }
  rescue ArgumentError
    render json: { error: "Unknown account kind." }, status: :unprocessable_content
  rescue Plaid::ApiError => error
    Rails.logger.error("Plaid link token failed: #{PlaidClient.error_code(error)}")
    render json: { error: "Couldn't start connecting to Plaid. Please try again." }, status: :bad_gateway
  end

  private
    def link_token
      if params[:plaid_item_id].present?
        PlaidLink.create_statement_dates_token(Current.user.plaid_items.find(params[:plaid_item_id]))
      else
        kind = params.expect(:kind)
        raise ArgumentError unless PlaidLink::KINDS.include?(kind)

        PlaidLink.create_token(user: Current.user, kind:)
      end
    end
end
