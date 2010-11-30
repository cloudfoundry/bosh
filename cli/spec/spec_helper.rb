require 'rspec/core'

$:.unshift(File.expand_path("../../lib", __FILE__))
require 'cli'

RSpec.configure do |c|
  c.color_enabled = true
end
