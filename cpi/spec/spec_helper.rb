require 'rspec/core'

$:.unshift(File.expand_path("../../lib", __FILE__))

require "sequel"
require "sequel/adapters/sqlite"
Sequel.sqlite(':memory:')

require 'cloud'

Bosh::Clouds::Config.configure

RSpec.configure do |c|
  c.color_enabled = true
end
