require File.expand_path('../../../spec/shared_spec_helper', __FILE__)

require 'rspec/its'
require 'rake'
require 'fakefs/spec_helpers'
require 'webmock/rspec'
require 'sequel'
require 'sequel/adapters/sqlite'
require 'cloud'

db = Sequel.sqlite(':memory:')

class VSphereSpecConfig
  attr_accessor :db
end

config = VSphereSpecConfig.new
config.db = db

Bosh::Clouds::Config.configure(config)

Dir.glob(File.expand_path('../support/**/*.rb', __FILE__)).each { |f| require f }

SPEC_ROOT = File.dirname(__FILE__)

def spec_asset(name)
  File.join(SPEC_ROOT, 'assets', name)
end
