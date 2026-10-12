# The Plaid API client, configured from encrypted credentials:
#
#   plaid:
#     client_id: ...
#     secret: ...
#     environment: sandbox # or production
module PlaidClient
  def self.api
    @api ||= begin
      credentials = Rails.application.credentials.plaid
      if credentials.blank?
        raise "Plaid credentials are missing. Add plaid.client_id, plaid.secret and plaid.environment with bin/rails credentials:edit"
      end

      configuration = Plaid::Configuration.new
      configuration.server_index = Plaid::Configuration::Environment.fetch(credentials.fetch(:environment, "sandbox"))
      configuration.api_key["PLAID-CLIENT-ID"] = credentials.fetch(:client_id)
      configuration.api_key["PLAID-SECRET"] = credentials.fetch(:secret)
      Plaid::PlaidApi.new(Plaid::ApiClient.new(configuration))
    end
  end

  # The error code from a failed Plaid call (e.g. "ITEM_LOGIN_REQUIRED").
  def self.error_code(error)
    JSON.parse(error.response_body.to_s)["error_code"]
  rescue JSON::ParserError
    nil
  end
end
