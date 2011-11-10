require 'rspec/core'

$:.unshift(File.expand_path("../../lib", __FILE__))
require 'health_monitor'

def spec_asset(filename)
  File.expand_path(File.join(File.dirname(__FILE__), "assets", filename))
end

def alert_payload(attrs = {})
  {
    :id => "foo",
    :severity => 2,
    :title => "Alert",
    :created_at => Time.now
  }.merge(attrs)
end

def heartbeat_payload(attrs = {})
  {
    :id => "foo",
    :timestamp => Time.now
  }.merge(attrs)
end

RSpec.configure do |c|
  c.color_enabled = true
end
