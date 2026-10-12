# Plaid connections: saves one after Plaid Link succeeds, turns on statement
# dates for one (after Link update mode), and disconnects one.
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

  def destroy
    plaid_item = Current.user.plaid_items.find(params[:id])
    name = plaid_item.institution_name.presence || "the bank"

    plaid_item.disconnect!
    redirect_to accounts_path, notice: "Disconnected #{name}.", status: :see_other
  rescue Plaid::ApiError => error
    Rails.logger.error("Plaid disconnect failed: #{PlaidClient.error_code(error)}")
    redirect_to accounts_path, alert: "Couldn't disconnect #{name}. Please try again.", status: :see_other
  end

  private
    def return_path
      { "accounts" => accounts_path, "transactions" => transactions_path }.fetch(params[:from], root_path)
    end
end
