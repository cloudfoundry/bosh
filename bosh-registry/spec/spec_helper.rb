require File.expand_path('../../../spec/shared_spec_helper', __FILE__)

require "fileutils"
require "logger"
require "tmpdir"
require "rack/test"

module SpecHelper
  class << self
    attr_accessor :logger
    attr_accessor :temp_dir

    def init
      ENV["RACK_ENV"] = "test"
      configure_logging
      configure_temp_dir

      require "bosh/registry"
      init_database
    end

    def configure_logging
      if ENV["DEBUG"]
        @logger = Logger.new(STDOUT)
      else
        path = File.expand_path("/tmp/spec.log", __FILE__)
        log_file = File.open(path, "w")
        log_file.sync = true
        @logger = Logger.new(log_file)
      end
    end

    def configure_temp_dir
      @temp_dir = Dir.mktmpdir
      ENV["TMPDIR"] = @temp_dir
      FileUtils.mkdir_p(@temp_dir)
      at_exit do
        begin
          if $!
            status = $!.is_a?(::SystemExit) ? $!.status : 1
          else
            status = 0
          end
          FileUtils.rm_rf(@temp_dir)
        ensure
          exit status
        end
      end
    end

    def init_database
      @migrations_dir = File.expand_path("../../db/migrations", __FILE__)

      Sequel.extension :migration

      @db = Sequel.sqlite(:database => nil, :max_connections => 32, :pool_timeout => 10)
      @db.loggers << @logger
      Bosh::Registry.db = @db

      run_migrations
    end

    def run_migrations
      Sequel::Migrator.apply(@db, @migrations_dir, nil)
    end

    def reset_database
      @db.execute("PRAGMA foreign_keys = OFF")
      @db.tables.each do |table|
        @db.drop_table(table)
      end
      @db.execute("PRAGMA foreign_keys = ON")
    end

    def reset
      reset_database
      run_migrations

      Bosh::Registry.db = @db
      Bosh::Registry.logger = @logger
    end
  end
end

SpecHelper.init

def valid_config
  {
    "logfile" => nil,
    "loglevel" => "debug",
    "http" => {
      "user" => "admin",
      "password" => "admin",
      "port" => 25777
    },
    "db" => {
      "connection_options" => {
        "max_connections" => 433,
        "pool_timeout" => 227,
      },
      "database" => "/:memory:",
      "adapter" => "sqlite"
    },
    "cloud" => {
      "plugin" => "dummy"
    }
  }
end

RSpec.configure do |rspec|
  rspec.before(:each) do
    SpecHelper.reset
    Bosh::Registry.logger = Logger.new(StringIO.new)
  end
end
