require "rspec"
require "logger"
require "tmpdir"

require "sequel"
require "sequel/adapters/sqlite"

def cloud_options
  {
    "warden" => warden_options,
    "stemcell" => stemcell_options,
  }
end

def warden_options
  {
    "unix_domain_socket" => "/tmp/warden.sock",
  }
end

def stemcell_options
  {
    "root" => "/var/vcap/stemcell",
  }
end

# DB migration
Sequel.extension :migration
db = Sequel.sqlite(':memory:')
migration = File.expand_path("../../db/migrations/warden_cpi", __FILE__)
Sequel::TimestampMigrator.new(db, migration, :table => "warden_cpi_schema").run

require "cloud"

class WardenConfig
  attr_accessor :logger, :db, :uuid
end

config = WardenConfig.new
config.db = db
config.logger = Logger.new("/dev/null")
config.uuid = "1024"

Bosh::Clouds::Config.configure(config)

require "cloud/warden"

def asset(file)
  File.join(File.dirname(__FILE__), "assets", file)
end
