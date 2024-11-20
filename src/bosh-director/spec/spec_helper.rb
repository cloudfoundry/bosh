$LOAD_PATH << File.expand_path(File.dirname(__FILE__))

require_relative '../../spec/shared/spec_helper'

SPEC_ROOT = File.dirname(__FILE__)
SPEC_ASSETS = File.join(SPEC_ROOT, 'assets')

require 'digest/sha1'
require 'fileutils'
require 'logging'
require 'minitar'
require 'pg'
require 'tempfile'
require 'tmpdir'
require 'zlib'

require 'webmock/rspec'
require 'factory_bot'

require 'db_migrator'

require 'bosh/director'

Dir.glob(File.join(File.dirname(__FILE__), 'support/**/*.rb')).each { |f| require(f) }

ENV['RACK_ENV'] = 'test'

module SpecHelper
  class << self
    include LoggingHelper

    def init
      init_database

      require 'factories'
    end

    def init_logger
      @init_logger ||= begin
                    name = "bosh-director-spec-logger-#{Process.pid}"
                    Logging::Logger.new(name).tap do |logger|
                      logger.add_appenders(
                        Logging.appenders.file(
                          "bosh-director-spec-logger-#{Process.pid}",
                          filename: File.join(BOSH_REPO_SRC_DIR, 'tmp', "#{name}.log"),
                          layout: ThreadFormatter.layout,
                        ),
                      )
                      logger.level = :debug
                    end
                  end
    end

    def spec_get_director_config
      YAML.load_file(File.join(SPEC_ASSETS, 'test-director-config.yml')).tap do |config|
        config['nats']['server_ca_path'] = File.join(SPEC_ASSETS, 'nats', 'nats_ca.pem')
        config['nats']['client_ca_certificate_path'] = File.join(SPEC_ASSETS, 'nats', 'nats_ca_certificate.pem')
        config['nats']['client_ca_private_key_path'] = File.join(SPEC_ASSETS, 'nats', 'nats_ca_private_key.pem')

        config['db']['adapter'] = db_helper.adapter
        config['db']['host'] = db_helper.host
        config['db']['database'] = db_helper.db_name
        config['db']['user'] = db_helper.username
        config['db']['password'] = db_helper.password
        config['db']['port'] = db_helper.port
      end
    end

    def init_database
      connect_database

      Bosh::Director::Config.db = @db

      Delayed::Worker.backend = :sequel

      run_migrations
    end

    def connect_database
      init_logger.info("Create database '#{db_helper.connection_string}'")
      db_helper.create_db

      Sequel.default_timezone = :utc
      @db =
        Sequel.connect(db_helper.connection_string, max_connections: 32, pool_timeout: 10).tap do |db|
          db.loggers << init_logger
          db.log_connection_info = true
        end
    end

    def disconnect_database
      if @db
        @db.disconnect
        init_logger.info("Drop database '#{db_helper.connection_string}'")
        db_helper.drop_db

        @db = nil
        @db_helper = nil
      end
    end

    def run_migrations
      DBMigrator.new(@db).migrate
    end

    def db_helper
      @db_helper ||= begin
                       db_options = {
                         type: ENV.fetch('DB', 'sqlite'),
                         name: "#{SecureRandom.uuid.delete('-')}_director",
                         username: ENV['DB_USER'],
                         password: ENV['DB_PASSWORD'],
                         host: ENV['DB_HOST'],
                         port: ENV['DB_PORT'],
                       }

                       SharedSupport::DBHelper.build(db_options: db_options)
                     end
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

    def reset_config(test_logger)
      Bosh::Director::Config.clear
      Bosh::Director::Config.db = @db
      Bosh::Director::Config.logger = test_logger
      Bosh::Director::Config.trusted_certs = ''
      Bosh::Director::Config.max_threads = 1
      Bosh::Director::Config.event_log = Bosh::Director::EventLog::Log.new
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

      init_logger.info("Truncating database '#{db_helper.connection_string}'")
      db_helper.truncate_db
    end
  end
end

SpecHelper.init

RSpec.configure do |config|
  config.include(FactoryBot::Syntax::Methods)

  config.before(:suite) do
    SpecHelper.setup_datasets
  end

  config.after(:suite) do
    SpecHelper.disconnect_database
  end

  config.around(:each) do |example|
    SpecHelper.reset_database(example)
  end

  config.before(:each) do
    SpecHelper.reset_config(per_spec_logger)
  end
end

def gzip(string)
  result = StringIO.new
  zio = Zlib::GzipWriter.new(result)
  zio.mtime = '1'
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
