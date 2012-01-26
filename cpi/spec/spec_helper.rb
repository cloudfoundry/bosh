require 'rspec/core'

$:.unshift(File.expand_path("../../lib", __FILE__))

require 'cloud'

Bosh::Clouds::Config.configure({})

RSpec.configure do |c|
  c.color_enabled = true
end
