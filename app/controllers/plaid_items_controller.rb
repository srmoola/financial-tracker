# Saves a connection after Plaid Link succeeds, then sends the user on.
class PlaidItemsController < ApplicationController
  def create
    plaid_item = PlaidItem.connect!(user: Current.user, public_token: params.expect(:public_token))

    flash[:notice] = "Connected #{plaid_item.institution_name.presence || "your account"}."
    render json: { redirect_url: return_path }
  rescue Plaid::ApiError => error
    Rails.logger.error("Plaid connect failed: #{PlaidClient.error_code(error)}")
    render json: { error: "Couldn't finish connecting your account. Please try again." }, status: :bad_gateway
  end

  # After the user allows statement dates in Link update mode (no token exchange needed).
  def statement_dates
    plaid_item = Current.user.plaid_items.find(params[:id])
    plaid_item.sync_statement_dates!(after_consent: true)

    name = plaid_item.institution_name.presence || "This bank"
    flash[:notice] = plaid_item.statement_dates_status == "available" ? "Statement dates are on for #{name}." : "#{name} doesn't share statement dates, so This month starts on the 1st."
    render json: { redirect_url: return_path }
  rescue Plaid::ApiError => error
    Rails.logger.error("Plaid statement dates failed: #{PlaidClient.error_code(error)}")
    render json: { error: "Couldn't turn on statement dates. Please try again." }, status: :bad_gateway
  end

  private
    def return_path
      { "accounts" => accounts_path, "transactions" => transactions_path }.fetch(params[:from], root_path)
    end
end
