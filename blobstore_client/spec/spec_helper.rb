require 'rspec'
require 'rspec/fire'
require 'blobstore_client'

require 'erb'
require 'tempfile'

def asset(filename)
  File.expand_path(File.join(File.dirname(__FILE__), 'assets', filename))
end

def erb_asset(filename, binding)
  file = Tempfile.new('erb_asset')
  file.write(ERB.new(File.read(asset(filename))).result(binding))
  file.flush
  file
end

RSpec.configure do |config|
  config.include(RSpec::Fire)
end

RSpec::Fire.configure do |config|
  config.verify_constant_names = true
end
