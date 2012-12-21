require "rspec"
require "logger"
require "tmpdir"

require "sequel"
require "sequel/adapters/sqlite"

def cloud_options
  {
    "warden" => warden_options,
    "stemcell" => stemcell_options,
    "agent" => agent_options,
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

def agent_options
  {
    "blobstore" => {
      "plugin" => "simple",
      "properties" => {},
    },
    "mbus" => "nats://nats:nats@localhost:4222",
    "ntp" => [],
  }
end

# DB migration
Sequel.extension :migration
db = Sequel.sqlite(":memory:")
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

class WardenCloudHelper
  attr_accessor :wardencloud
  def initialize
    @wardencloud = nil
  end

  def method_missing method, *args, &block
    if @wardencloud.respond_to? method, true
        @wardencloud.send(method, *args, &block)
    else
      raise NoMethodError
    end
  end
end

require "cloud/warden"

def asset(file)
  File.join(File.dirname(__FILE__), "assets", file)
end

def image_file(disk_id)
  "#{disk_id}.img"
end

module Bosh::Clouds
  class Warden
    attr_accessor :delegate
  end
end
