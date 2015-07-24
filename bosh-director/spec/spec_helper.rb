$: << File.expand_path('..', __FILE__)

require File.expand_path('../../../spec/shared_spec_helper', __FILE__)

require 'digest/sha1'
require 'fileutils'
require 'logging'
require 'pg'
require 'tempfile'
require 'tmpdir'
require 'zlib'

require 'archive/tar/minitar'
require 'machinist/sequel'
require 'sham'
require 'support/buffered_logger'

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each { |f| require(f) }

DIRECTOR_TEST_CERTS="these\nare\nthe\ncerts"
DIRECTOR_TEST_CERTS_SHA1=Digest::SHA1.hexdigest DIRECTOR_TEST_CERTS

RSpec.configure do |config|
  config.include Bosh::Director::Test::TaskHelpers
end

module SpecHelper
  class << self
    include BufferedLogger

    attr_accessor :temp_dir

    def init
      ENV["RACK_ENV"] = "test"
      configure_init_logger
      configure_temp_dir

      require "bosh/director"

      init_database

      require "blueprints"
    end

    # init_logger is only used before the tests start.
    # Inside each test BufferedLogger will be used.
    def configure_init_logger
      file_path = File.expand_path('/tmp/spec.log', __FILE__)

      @init_logger = Logging::Logger.new('TestLogger')
      @init_logger.add_appenders(
        Logging.appenders.file(
          'TestLogFile',
          filename: file_path,
          layout: ThreadFormatter.layout
        )
      )
      @init_logger.level = :debug
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
      Sequel.extension :migration

      connect_database(@temp_dir)

      run_migrations
    end

    def connect_database(path)
      db     = ENV['DB_CONNECTION']     || "sqlite://#{File.join(path, "director.db")}"
      dns_db = ENV['DNS_DB_CONNECTION'] || "sqlite://#{File.join(path, "dns.db")}"

      db_opts = {:max_connections => 32, :pool_timeout => 10}

      @db = Sequel.connect(db, db_opts)
      @db.loggers << (logger || @init_logger)
      Bosh::Director::Config.db = @db

      @dns_db = Sequel.connect(dns_db, db_opts)
      @dns_db.loggers << (logger || @init_logger)
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

    def reset(logger)
      reset_database

      Bosh::Director::Config.clear
      Bosh::Director::Config.db = @db
      Bosh::Director::Config.dns_db = @dns_db
      Bosh::Director::Config.logger = logger
      Bosh::Director::Config.trusted_certs = ''
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

    SpecHelper.reset(logger)
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
  events = @event_buffer.string.split("\n").map do |line|
    JSON.parse(line)
  end

  yield events
end

def strip_heredoc(str)
  indent = str.scan(/^[ \t]*(?=\S)/).min.size || 0
  str.gsub(/^[ \t]{#{indent}}/, '')
end

module ManifestHelper
  class << self
    def default_deployment_manifest(overrides = {})
      {
        'name' => 'deployment-name',
        'releases' => [release],
        'update' => {
          'max_in_flight' => 10,
          'canaries' => 2,
          'canary_watch_time' => 1000,
          'update_watch_time' => 1000,
        },
      }.merge(overrides)
    end

    def default_legacy_manifest(overrides = {})
      (default_deployment_manifest.merge(default_iaas_manifest)).merge(overrides)
    end

    def default_iaas_manifest(overrides = {})
      {
      'networks' => [ManifestHelper::network],
      'resource_pools' => [ManifestHelper::resource_pool],
      'compilation' => {
        'workers' => 1,
        'network'=>'network-name',
        'cloud_properties' => {},
        },
      }.merge(overrides)
    end

    def default_manifest_with_jobs(overrides = {})
      {
        'name' => 'deployment-name',
        'releases' => [release],
        'jobs' => [job],
        'update' => {
            'max_in_flight' => 10,
            'canaries' => 2,
            'canary_watch_time' => 1000,
            'update_watch_time' => 1000,
        },
      }.merge(overrides)
    end

    def release(overrides = {})
      {
        'name' => 'release-name',
        'version' => 'latest',
      }.merge(overrides)
    end

    def network(overrides = {})
      { 'name' => 'network-name', 'subnets' => [] }.merge(overrides)
    end

    def disk_pool(name='dp-name')
      {'name' => name, 'disk_size' => 10000}.merge(overrides)
    end

    def job(overrides = {})
      {
        'name' => 'job-name',
        'resource_pool' => 'rp-name',
        'instances' => 1,
        'networks' => [{'name' => 'network-name'}],
        'templates' => [{'name' => 'template-name', 'release' => 'release-name'}]
      }.merge(overrides)
    end

    def resource_pool(overrides = {})
      {
        'name' => 'rp-name',
        'network'=>'network-name',
        'stemcell'=> {'name' => 'default','version'=>'1'},
        'cloud_properties'=>{}
      }.merge(overrides)
    end
  end
end
