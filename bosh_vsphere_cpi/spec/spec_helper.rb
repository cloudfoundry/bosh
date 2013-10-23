require 'rspec'
require 'rspec/fire'
require 'sequel'
require 'sequel/adapters/sqlite'

Sequel.extension :migration
db = Sequel.sqlite(':memory:')
migration = File.expand_path('../../db/migrations', __FILE__)
Sequel::TimestampMigrator.new(db, migration, :table => 'vsphere_cpi_schema').run

require 'cloud'
require 'cloud/vsphere'

class VSphereSpecConfig
  attr_accessor :db, :logger, :uuid
end

config = VSphereSpecConfig.new
config.db = db
config.logger = Logger.new(STDOUT)
config.logger.level = Logger::ERROR
config.uuid = '123'

Bosh::Clouds::Config.configure(config)
VSphereCloud::Config.logger = config.logger

RSpec.configure do |config|
  config.include(RSpec::Fire)
end
