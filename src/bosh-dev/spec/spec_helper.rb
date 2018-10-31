require File.expand_path('../../../spec/shared/spec_helper', __FILE__)

require 'rake'
require 'fakefs/spec_helpers'
require 'webmock/rspec'
require 'sequel'
require 'sequel/adapters/sqlite'
require 'support/buffered_logger'

Dir.glob(File.expand_path('../support/**/*.rb', __FILE__)).each { |f| require(f) }

SPEC_ROOT = File.dirname(__FILE__)

supported = Bosh::Dev::RubyVersion.supported?(RUBY_VERSION)

raise "using unsupported ruby-version (#{RUBY_VERSION}) please install one of the following #{Bosh::Dev::RubyVersion}" unless supported

def spec_asset(name)
  File.join(SPEC_ROOT, 'assets', name)
end
