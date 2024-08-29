$LOAD_PATH << File.expand_path(__dir__)

require_relative '../../spec/shared/spec_helper'
require_relative '../../spec/support/deployments'

require 'digest/sha1'
require 'fileutils'
require 'logging'
require 'pg'
require 'tempfile'
require 'tmpdir'
require 'zlib'
require 'timecop'
require 'webmock/rspec'

require 'minitar'
require 'active_support' # TODO: remove once factory_bot > 6.4.6 is released
require 'factory_bot'
require 'support/buffered_logger'

Dir.glob(File.expand_path('support/**/*.rb', __dir__)).each { |f| require(f) }

DIRECTOR_TEST_CERTS = "these\nare\nthe\ncerts".freeze
DIRECTOR_TEST_CERTS_SHA1 = ::Digest::SHA1.hexdigest DIRECTOR_TEST_CERTS

RSpec.configure do |config|
  config.include Bosh::Director::Test::TaskHelpers
end

module SpecHelper
  class << self
    include BufferedLogger

    attr_accessor :temp_dir

    def init
      ENV['RACK_ENV'] = 'test'
      configure_init_logger
      configure_temp_dir

      require 'bosh/director'

      init_database

      require 'factories'
    end

    # init_logger is only used before the tests start.
    # Inside each test BufferedLogger will be used.
    def configure_init_logger
      file_path = File.expand_path('/tmp/spec.log', __dir__)

      @init_logger = Logging::Logger.new('TestLogger')
      @init_logger.add_appenders(
        Logging.appenders.file(
          'TestLogFile',
          filename: file_path,
          layout: ThreadFormatter.layout,
        ),
      )
      @init_logger.level = :debug
    end

    def configure_temp_dir
      @temp_dir = Bosh::Director::Config.generate_temp_dir
    end

    def spec_get_director_config
      config = YAML.load_file(File.expand_path('assets/test-director-config.yml', File.dirname(__FILE__)))

      config['nats']['server_ca_path'] = File.expand_path('assets/nats/nats_ca.pem', File.dirname(__FILE__))
      config['nats']['client_ca_certificate_path'] = File.expand_path(
        'assets/nats/nats_ca_certificate.pem',
        File.dirname(__FILE__),
      )
      config['nats']['client_ca_private_key_path'] = File.expand_path(
        'assets/nats/nats_ca_private_key.pem',
        File.dirname(__FILE__),
      )
      config['db']['adapter'] = @director_db_helper.adapter
      config['db']['host'] = @director_db_helper.host
      config['db']['database'] = @director_db_helper.db_name
      config['db']['user'] = @director_db_helper.username
      config['db']['password'] = @director_db_helper.password
      config['db']['port'] = @director_db_helper.port

      config
    end

    def init_database
      @db_name = SecureRandom.uuid.delete('-')
      connection_string = ENV['DB_URI']
      db_options = {}

      if !connection_string
        db_options.merge!({
          username: ENV['DB_USER'],
          password: ENV['DB_PASSWORD'],
          host: ENV['DB_HOST'] || '127.0.0.1',
        }.compact)
      else
        uri = URI.parse(connection_string)
        db_options.merge!({
          username: uri.user,
          password: uri.password,
          host: uri.host,
          port: uri.port,
        }.compact)
      end

      case ENV.fetch('DB', 'sqlite')
      when 'postgresql'
        require File.expand_path('../../bosh-dev/lib/bosh/dev/sandbox/postgresql', File.dirname(__FILE__))
        db_options[:port] ||= 5432

        @director_db_helper = Bosh::Dev::Sandbox::Postgresql.new(
          "#{@db_name}_director",
          Bosh::Core::Shell.new,
          @init_logger,
          db_options,
        )
      when 'mysql'
        require File.expand_path('../../bosh-dev/lib/bosh/dev/sandbox/mysql', File.dirname(__FILE__))
        db_options[:port] = 3306

        @director_db_helper = Bosh::Dev::Sandbox::Mysql.new(
          "#{@db_name}_director",
          Bosh::Core::Shell.new,
          @init_logger,
          db_options,
        )
      when 'sqlite'
        require File.expand_path('../../bosh-dev/lib/bosh/dev/sandbox/sqlite', File.dirname(__FILE__))
        @director_db_helper = Bosh::Dev::Sandbox::Sqlite.new(File.join(@temp_dir, "#{@db_name}_director.sqlite"), @init_logger)
      else
        raise "Unsupported DB value: #{ENV['DB']}"
      end

      @director_db_helper.create_db

      @director_migrations = File.expand_path('../db/migrations/director', __dir__)
      Sequel.extension :migration

      connect_database

      Sequel::Deprecation.output = false
      Delayed::Worker.backend = :sequel
      Sequel::Deprecation.output = $stderr

      run_migrations
    end

    def connect_database
      db_opts = { max_connections: 32, pool_timeout: 10 }

      Sequel.default_timezone = :utc
      @director_db = Sequel.connect(@director_db_helper.connection_string, db_opts)
      @director_db.loggers << (logger || @init_logger)
      @director_db.log_connection_info = true
      Bosh::Director::Config.db = @director_db
    end

    def disconnect_database
      if @director_db
        @director_db.disconnect
        @director_db_helper.drop_db

        @director_db = nil
        @director_db_helper = nil
      end
    end

    def run_migrations
      Sequel::Migrator.apply(@director_db, @director_migrations, nil)
    end

    def setup_datasets
      Bosh::Director::Models.constants.each do |e|
        c = Bosh::Director::Models.const_get(e)
        c.dataset = @director_db[c.simple_table.gsub(/[`"]/, '').to_sym] if c.is_a?(Class) && c.ancestors.include?(Sequel::Model)
      end

      Delayed::Backend::Sequel.constants.each do |e|
        c = Delayed::Backend::Sequel.const_get(e)
        c.dataset = @director_db[c.simple_table.gsub(/[`"]/, '').to_sym] if c.is_a?(Class) && c.ancestors.include?(Sequel::Model)
      end
    end

    def reset(logger)
      Bosh::Director::Config.clear
      Bosh::Director::Config.db = @director_db
      Bosh::Director::Config.logger = logger
      Bosh::Director::Config.trusted_certs = ''
      Bosh::Director::Config.max_threads = 1
    end

    def reset_database(example)
      if example.metadata[:truncation] && ENV.fetch('DB', 'sqlite') != 'sqlite'
        example.run
      else
        Sequel.transaction([@director_db], rollback: :always, auto_savepoint: true) do
          example.run
        end
      end

      Bosh::Director::Config.db&.disconnect

      return unless example.metadata[:truncation]

      @director_db_helper.truncate_db
    end
  end
end

SpecHelper.init

RSpec.configure do |rspec|
  rspec.around(:each) do |example|
    SpecHelper.reset_database(example)
  end

  rspec.include FactoryBot::Syntax::Methods

  rspec.before(:each) do
    SpecHelper.reset(logger)
    @event_buffer = StringIO.new
    @event_log = Bosh::Director::EventLog::Log.new(@event_buffer)
    Bosh::Director::Config.event_log = @event_log

    audit_logger = instance_double(Bosh::Director::AuditLogger)
    allow(Bosh::Director::AuditLogger).to receive(:instance).and_return(audit_logger)
    allow(audit_logger).to receive(:info)

    threadpool = instance_double(Bosh::Director::ThreadPool)
    allow(Bosh::Director::ThreadPool).to receive(:new).and_return(threadpool)
    allow(threadpool).to receive(:wrap).and_yield(threadpool)
    allow(threadpool).to receive(:process).and_yield
    allow(threadpool).to receive(:wait)
  end

  rspec.after(:each) { Timecop.return }

  rspec.before(:suite) do
    SpecHelper.setup_datasets
  end

  rspec.after(:suite) do
    SpecHelper.disconnect_database
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

def check_event_log(task_id)
  return if Bosh::Director::Models::Task.first(id: task_id).event_output.nil?

  events = Bosh::Director::Models::Task.first(id: task_id).event_output.split("\n").map do |line|
    JSON.parse(line)
  end

  yield events
end

def linted_rack_app(app)
  Rack::Builder.new do
    use Rack::Lint
    run app
  end
end
