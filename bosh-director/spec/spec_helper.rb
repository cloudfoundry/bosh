$: << File.expand_path('..', __FILE__)

require File.expand_path('../../../spec/shared/spec_helper', __FILE__)

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

Dir.glob(File.expand_path('../support/**/*.rb', __FILE__)).each { |f| require(f) }

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
      @temp_dir = Bosh::Director::Config.generate_temp_dir
    end

    def init_database
      @dns_migrations = File.expand_path("../../db/migrations/dns", __FILE__)
      @director_migrations = File.expand_path("../../db/migrations/director", __FILE__)
      Sequel.extension :migration

      connect_database(@temp_dir)
      Delayed::Worker.backend = :sequel

      run_migrations
    end

    def connect_database(path)
      db     = ENV['DB_CONNECTION']     || "sqlite://#{File.join(path, "director.db")}"
      dns_db = ENV['DNS_DB_CONNECTION'] || "sqlite://#{File.join(path, "dns.db")}"

      db_opts = {:max_connections => 32, :pool_timeout => 10}

      Sequel.default_timezone = :utc
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

    def reset(logger)
      Bosh::Director::Config.clear
      Bosh::Director::Config.db = @db
      Bosh::Director::Config.dns_db = @dns_db
      Bosh::Director::Config.logger = logger
      Bosh::Director::Config.trusted_certs = ''
      Bosh::Director::Config.max_threads = 1

      Bosh::Director::Models.constants.each do |e|
        c = Bosh::Director::Models.const_get(e)
        c.db = @db if c.kind_of?(Class) && c.ancestors.include?(Sequel::Model)
      end

      Delayed::Backend::Sequel.constants.each do |e|
        c = Delayed::Backend::Sequel.const_get(e)
        c.db = @db if c.kind_of?(Class) && c.ancestors.include?(Sequel::Model)
      end

      Bosh::Director::Models::Dns.constants.each do |e|
        c = Bosh::Director::Models::Dns.const_get(e)
        c.db = @dns_db if c.kind_of?(Class) && c.ancestors.include?(Sequel::Model)
      end
    end

    def reset_database(example)
      Sequel.transaction([@db, @dns_db], :rollback=>:always, :auto_savepoint=>true) { example.run }

      @db.run('UPDATE sqlite_sequence SET seq = 0')
      @dns_db.run('UPDATE sqlite_sequence SET seq = 0')
    end
  end
end

SpecHelper.init

BD = Bosh::Director

RSpec.configure do |rspec|
  rspec.around(:each) do |example|
    SpecHelper.reset_database(example)
  end

  rspec.before(:each) do
    SpecHelper.reset(logger)
    @event_buffer = StringIO.new
    @event_log = Bosh::Director::EventLog::Log.new(@event_buffer)
    Bosh::Director::Config.event_log = @event_log

    threadpool = instance_double(Bosh::Director::ThreadPool)
    allow(Bosh::Director::ThreadPool).to receive(:new).and_return(threadpool)
    allow(threadpool).to receive(:wrap).and_yield(threadpool)
    allow(threadpool).to receive(:process).and_yield
    allow(threadpool).to receive(:wait)
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

    def manual_network(overrides = {})
      ManifestHelper::network({
          'type' => 'manual',
          'subnets' => [{
              'range' => '10.0.0.1/24',
              'gateway' => '10.0.0.1'
            }]
        }).merge(overrides)
    end

    def disk_pool(name='dp-name')
      {'name' => name, 'disk_size' => 10000}
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
