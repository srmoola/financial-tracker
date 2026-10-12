require "rails_helper"

RSpec.describe PlaidClient do
  around do |example|
    PlaidClient.instance_variable_set(:@api, nil)
    example.run
  ensure
    PlaidClient.instance_variable_set(:@api, nil)
  end

  before do
    stub_const("ENV", ENV.to_h.merge("PLAID_CLIENT_ID" => "client-id", "PLAID_SECRET" => "secret", "PLAID_ENV" => "production"))
  end

  it "uses Plaid's Sandbox outside production, whatever PLAID_ENV says" do
    expect(PlaidClient.environment).to eq("sandbox")
    expect(PlaidClient.api.api_client.config.server_index).to eq(Plaid::Configuration::Environment["sandbox"])
  end

  it "uses Plaid's Production in production" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))

    expect(PlaidClient.environment).to eq("production")
    expect(PlaidClient.api.api_client.config.server_index).to eq(Plaid::Configuration::Environment["production"])
  end
end
