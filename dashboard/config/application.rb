require File.expand_path('../boot', __FILE__)

require "action_controller/railtie"
require "action_mailer/railtie"
require "rails/test_unit/railtie"

Bundler.require(:default, Rails.env) if defined?(Bundler)

module Dashboard
  class Application < Rails::Application
    config.action_view.javascript_expansions[:defaults] = %w()
    config.encoding = "utf-8"
    config.filter_parameters += [:password]
  end
end
