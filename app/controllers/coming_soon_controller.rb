class ComingSoonController < ApplicationController
  DESCRIPTIONS = {
    "subscriptions" => "See every recurring charge in one place, and spot the ones you forgot about.",
    "taxes" => "An estimate of what you'll owe this year, based on your income and investments."
  }.freeze

  def show
    @section = helpers.nav_item(params[:section].to_sym)
    @description = DESCRIPTIONS.fetch(params[:section])
  end
end
