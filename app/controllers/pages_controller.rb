class PagesController < ApplicationController
  allow_unauthenticated_access only: :home

  def home
    render :landing, layout: "application" unless authenticated?
  end
end
