class AccountsController < ApplicationController
  def index
    @plaid_items = Current.user.plaid_items.includes(:accounts).order(:created_at)
  end
end
