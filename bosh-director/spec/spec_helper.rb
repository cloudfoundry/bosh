$: << File.expand_path('..', __FILE__)

require File.expand_path('../../../spec/shared_spec_helper', __FILE__)

require 'digest/sha1'
require 'fileutils'
require 'logger'
require 'pg'
require 'tempfile'
require 'tmpdir'
require 'zlib'

require 'archive/tar/minitar'
require 'rspec'
require 'rspec/its'
require 'machinist/sequel'
require 'sham'

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each { |f| require(f) }

RSpec.configure do |config|
  config.include Bosh::Director::Test::TaskHelpers
end

module SpecHelper
  class << self
    attr_accessor :logger
    attr_accessor :temp_dir

    def init
      ENV["RACK_ENV"] = "test"
      configure_logging
      configure_temp_dir

      require "bosh/director"
      @logger.formatter = ThreadFormatter.new

      init_database

      require "blueprints"
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
      Bosh::Director::Config.patch_sqlite

      @dns_migrations = File.expand_path("../../db/migrations/dns", __FILE__)
      @director_migrations = File.expand_path("../../db/migrations/director", __FILE__)
      vsphere_cpi_path = $LOAD_PATH.find { |p| File.exist?(File.join(p, File.join("cloud", "vsphere"))) }
      @vsphere_cpi_migrations = File.expand_path("../db/migrations", vsphere_cpi_path)

      Sequel.extension :migration

      connect_database(@temp_dir)

      run_migrations
    end

    def connect_database(path)
      db     = ENV['DB_CONNECTION']     || "sqlite://#{File.join(path, "director.db")}"
      dns_db = ENV['DNS_DB_CONNECTION'] || "sqlite://#{File.join(path, "dns.db")}"

      db_opts = {:max_connections => 32, :pool_timeout => 10}

      @db = Sequel.connect(db, db_opts)
      @db.loggers << @logger
      Bosh::Director::Config.db = @db

      @dns_db = Sequel.connect(dns_db, db_opts)
      @dns_db.loggers << @logger
      Bosh::Director::Config.dns_db = @dns_db
    end

    def disconnect_database
      if @db
        @db.disconnect
        @db = nil
      end

      if @dns_db
        @dns_db.disconnect
        @dns_db = nil
      end
    end

    def run_migrations
      Sequel::Migrator.apply(@dns_db, @dns_migrations, nil)
      Sequel::Migrator.apply(@db, @director_migrations, nil)
      Sequel::TimestampMigrator.new(@db, @vsphere_cpi_migrations, :table => "vsphere_cpi_schema").run
    end

    def reset_database
      disconnect_database

      if @db_dir && File.directory?(@db_dir)
        FileUtils.rm_rf(@db_dir)
      end

      @db_dir = Dir.mktmpdir(nil, @temp_dir)
      FileUtils.cp(Dir.glob(File.join(@temp_dir, "*.db")), @db_dir)

      connect_database(@db_dir)

      Bosh::Director::Models.constants.each do |e|
        c = Bosh::Director::Models.const_get(e)
        c.db = @db if c.kind_of?(Class) && c.ancestors.include?(Sequel::Model)
      end

      Bosh::Director::Models::Dns.constants.each do |e|
        c = Bosh::Director::Models::Dns.const_get(e)
        c.db = @dns_db if c.kind_of?(Class) && c.ancestors.include?(Sequel::Model)
      end
    end

    def reset
      reset_database

      Bosh::Director::Config.clear
      Bosh::Director::Config.db = @db
      Bosh::Director::Config.dns_db = @dns_db
      Bosh::Director::Config.logger = @logger
    end
  end
end

SpecHelper.init

BD = Bosh::Director

RSpec.configure do |rspec|
  rspec.before(:each) do
    unless $redis_63790_started
      redis_config = Tempfile.new('redis_config')
      File.write(redis_config.path, 'port 63790')
      redis_pid = Process.spawn('redis-server', redis_config.path, out: '/dev/null')
      $redis_63790_started = true

      at_exit do
        begin
          if $!
            status = $!.is_a?(::SystemExit) ? $!.status : 1
          else
            status = 0
          end
          redis_config.delete
          Process.kill("KILL", redis_pid)
        ensure
          exit status
        end
      end
    end

    SpecHelper.reset
    @event_buffer = StringIO.new
    @event_log = Bosh::Director::EventLog::Log.new(@event_buffer)
    Bosh::Director::Config.event_log = @event_log
  end
end

def gzip(string)
  result = StringIO.new
  zio = Zlib::GzipWriter.new(result, nil, nil)
  zio.mtime = 1
  zio.write(string)
  zio.close
  result.string
end

def check_event_log
  pos = @event_buffer.tell
  @event_buffer.rewind

  events = @event_buffer.read.split("\n").map do |line|
    JSON.parse(line)
  end

  yield events
ensure
  @event_buffer.seek(pos)
end


