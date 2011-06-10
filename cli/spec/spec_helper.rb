require 'rspec/core'

$:.unshift(File.expand_path("../../lib", __FILE__))
require 'cli'

def spec_asset(filename)
  File.expand_path(File.join(File.dirname(__FILE__), "assets", filename))
end

File.umask(022)

RSpec.configure do |c|
  c.color_enabled = true
end
