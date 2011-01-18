class HomepageController < ApplicationController
  before_filter :director_credentials_required

  def index
    @javascripts = %w(dashboard_updater)
  end
end
