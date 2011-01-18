require File.expand_path('../boot', __FILE__)

require "rails/all"

Bundler.require(:default, Rails.env) if defined?(Bundler)

module Dashboard
  class Application < Rails::Application
    config.action_view.javascript_expansions[:defaults] = %w()
    config.encoding = "utf-8"
    config.filter_parameters += [:password]
  end
end
