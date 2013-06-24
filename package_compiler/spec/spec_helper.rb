require 'rspec/core'

require 'coveralls'
Coveralls.wear!

require 'package_compiler'

def spec_asset(filename)
  File.expand_path(File.join(File.dirname(__FILE__), "assets", filename))
end
