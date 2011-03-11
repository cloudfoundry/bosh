require "rspec/core"

$:.unshift(File.expand_path("../../lib", __FILE__))
require "monit_api"

RSpec.configure do |c|
  c.color_enabled = true
end
