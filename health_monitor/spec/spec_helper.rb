require 'rspec/core'

$:.unshift(File.expand_path("../../lib", __FILE__))
require 'health_monitor'

def spec_asset(filename)
  File.expand_path(File.join(File.dirname(__FILE__), "assets", filename))
end

RSpec.configure do |c|
  c.color_enabled = true
end
