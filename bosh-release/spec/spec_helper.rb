require 'rspec/core'

require 'bosh/release'

def spec_asset(filename)
  File.expand_path(File.join(File.dirname(__FILE__), "assets", filename))
end
