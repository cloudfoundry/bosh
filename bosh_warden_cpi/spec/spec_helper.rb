require "rspec"
require "logger"
require "tmpdir"

require "sequel"
require "sequel/adapters/sqlite"

module Helper
  def cloud_options
    {
      "agent" => agent_options,
      "warden" => warden_options,
      "stemcell" => stemcell_options,
      "disk" => disk_options,
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

  def warden_options
    {
      "unix_domain_socket" => "/tmp/warden.sock",
    }
  end

  def stemcell_options
    @stemcell_root ||= File.join(tmpdir, "stemcell").tap do |e|
      FileUtils.mkdir_p(e)
    end

    {
      "root" => @stemcell_root,
    }
  end

  def disk_options
    @disk_root ||= File.join(tmpdir, "disk").tap do |e|
      FileUtils.mkdir_p(e)
    end

    {
      "root" => @disk_root,
    }
  end

  def tmpdir
    @tmpdir ||= Dir.mktmpdir
  end
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

RSpec.configure do |config|
  config.include(Helper)
end