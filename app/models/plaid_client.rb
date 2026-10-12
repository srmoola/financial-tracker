# The Plaid API client. Keys come from environment variables (locally, the
# gitignored .env file loaded by Docker Compose), falling back to encrypted
# credentials:
#
#   PLAID_CLIENT_ID / PLAID_SECRET / PLAID_ENV (sandbox or production)
#   or credentials: plaid: { client_id:, secret:, environment: }
module PlaidClient
  def self.api
    @api ||= begin
      credentials = Rails.application.credentials.plaid || {}
      client_id = ENV["PLAID_CLIENT_ID"].presence || credentials[:client_id]
      secret = ENV["PLAID_SECRET"].presence || credentials[:secret]
      environment = ENV["PLAID_ENV"].presence || credentials[:environment] || "sandbox"
      raise "Plaid keys are missing. Set PLAID_CLIENT_ID and PLAID_SECRET (e.g. in .env)." if client_id.blank? || secret.blank?

      configuration = Plaid::Configuration.new
      configuration.server_index = Plaid::Configuration::Environment.fetch(environment)
      configuration.api_key["PLAID-CLIENT-ID"] = client_id
      configuration.api_key["PLAID-SECRET"] = secret
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
