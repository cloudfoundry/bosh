require 'rspec'
require 'blobstore_client'
require 'erb'
require 'tempfile'

require File.expand_path('../support/shared_examples/base', __FILE__)

RSpec.configure do |config|
  config.raise_errors_for_deprecations!
end

def asset(filename)
  File.expand_path(File.join(File.dirname(__FILE__), 'assets', filename))
end

def erb_asset(filename, binding)
  file = Tempfile.new('erb_asset')
  file.write(ERB.new(File.read(asset(filename))).result(binding))
  file.flush
  file
end
