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
require 'factory_bot'
require 'support/buffered_logger'

require 'db_migrator'

require 'bosh/dev/db/db_helper'

Dir.glob(File.expand_path('support/**/*.rb', __dir__)).each { |f| require(f) }

DIRECTOR_TEST_CERTS = "these\nare\nthe\ncerts".freeze
DIRECTOR_TEST_CERTS_SHA1 = ::Digest::SHA1.hexdigest DIRECTOR_TEST_CERTS

module SpecHelper
  class << self
    include BufferedLogger

    attr_accessor :temp_dir

    def init
      ENV['RACK_ENV'] = 'test'
      configure_init_logger

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
      config['db']['adapter'] = @db_helper.adapter
      config['db']['host'] = @db_helper.host
      config['db']['database'] = @db_helper.db_name
      config['db']['user'] = @db_helper.username
      config['db']['password'] = @db_helper.password
      config['db']['port'] = @db_helper.port

      config
    end

    def init_database
      connect_database

      @db.loggers << (logger || @init_logger)
      @db.log_connection_info = true
      Bosh::Director::Config.db = @db

      Delayed::Worker.backend = :sequel

      run_migrations
    end

    def connect_database
      db_options = {
        type: ENV.fetch('DB', 'sqlite'),
        name: "#{SecureRandom.uuid.delete('-')}_director",
        username: ENV['DB_USER'],
        password: ENV['DB_PASSWORD'],
        host: ENV['DB_HOST'],
        port: ENV['DB_PORT'],
      }

      @db_helper =
        Bosh::Dev::DB::DBHelper.build(db_options: db_options, logger: @init_logger)

      @db_helper.create_db

      Sequel.default_timezone = :utc
      @db = Sequel.connect(@db_helper.connection_string, max_connections: 32, pool_timeout: 10)
    end

    def disconnect_database
      if @db
        @db.disconnect
        @db_helper.drop_db

        @db = nil
        @db_helper = nil
      end
    end

    def run_migrations
      DBMigrator.new(@db).migrate
    end

    def setup_datasets
      Bosh::Director::Models.constants.each do |e|
        c = Bosh::Director::Models.const_get(e)
        c.dataset = @db[c.simple_table.gsub(/[`"]/, '').to_sym] if c.is_a?(Class) && c.ancestors.include?(Sequel::Model)
      end

      Delayed::Backend::Sequel.constants.each do |e|
        c = Delayed::Backend::Sequel.const_get(e)
        c.dataset = @db[c.simple_table.gsub(/[`"]/, '').to_sym] if c.is_a?(Class) && c.ancestors.include?(Sequel::Model)
      end
    end

    def reset(logger)
      Bosh::Director::Config.clear
      Bosh::Director::Config.db = @db
      Bosh::Director::Config.logger = logger
      Bosh::Director::Config.trusted_certs = ''
      Bosh::Director::Config.max_threads = 1
    end

    def reset_database(example)
      if example.metadata[:truncation] && ENV.fetch('DB', 'sqlite') != 'sqlite'
        example.run
      else
        Sequel.transaction([@db], rollback: :always, auto_savepoint: true) do
          example.run
        end
      end

      Bosh::Director::Config.db&.disconnect

      return unless example.metadata[:truncation]

      @db_helper.truncate_db
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
