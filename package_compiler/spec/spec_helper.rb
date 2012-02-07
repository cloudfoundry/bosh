require 'rspec/core'

$:.unshift(File.expand_path("../../lib", __FILE__))
require 'package_compiler'

def spec_asset(filename)
  File.expand_path(File.join(File.dirname(__FILE__), "assets", filename))
end
