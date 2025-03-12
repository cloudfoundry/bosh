SPEC_ROOT = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH << SPEC_ROOT

require File.expand_path('../../spec/shared/spec_helper', SPEC_ROOT)

require 'digest/sha1'
require 'fileutils'
require 'logging'
require 'minitar'
require 'pg'
require 'tempfile'
require 'tmpdir'
require 'yaml'
require 'zlib'

require 'db_migrator'
require 'bosh/director'
require 'bosh/template'

require 'common/deep_copy'

require 'webmock/rspec'

Dir.glob(File.join(SPEC_ROOT, 'support/**/*.rb')).each { |f| require(f) }

ENV['RACK_ENV'] = 'test'

module SpecHelper
  SPEC_ASSETS = File.join(SPEC_ROOT, 'assets')

  class << self
    attr_accessor :database

    def create_and_migrate_database
      @database = begin
                    database_logger.info("Creating database '#{db_helper.connection_string}'")
                    db_helper.create_db

                    Sequel.default_timezone = :utc
                    Sequel.connect(db_helper.connection_string, max_connections: 32, pool_timeout: 10).tap do |sequel_db|
                      sequel_db.loggers << database_logger
                      sequel_db.log_connection_info = true
                      Bosh::Director::Config.db = sequel_db

                      DBMigrator.new(sequel_db).migrate

                      Bosh::Director::Models.constants.each do |constant_sym|
                        constant = Bosh::Director::Models.const_get(constant_sym)
                        set_dataset_for(constant, sequel_db) if sequel_model?(constant)
                      end

                      Delayed::Worker.backend = :sequel
                      Delayed::Backend::Sequel.constants.each do |constant_sym|
                        constant = Delayed::Backend::Sequel.const_get(constant_sym)
                        set_dataset_for(constant, sequel_db) if sequel_model?(constant)
                      end

                      require 'factories'
                    end
                  end
    end

    def reset_database(database, example)
      database_logger.info("Resetting database '#{db_helper.connection_string}'")
      if example.metadata[:truncation] && ENV.fetch('DB', 'sqlite') != 'sqlite'
        example.run
      else
        Sequel.transaction([database], rollback: :always, auto_savepoint: true) do
          example.run
        end
      end

      Bosh::Director::Config.db&.disconnect # prevent "too many connections" error

      if example.metadata[:truncation]
        database_logger.info("Truncating database '#{db_helper.connection_string}'")
        db_helper.truncate_db
      end
    end

    def director_config_hash
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

    def reset_director_config(database, test_logger)
      Bosh::Director::Config.clear
      Bosh::Director::Config.db = database
      Bosh::Director::Config.logger = test_logger
      Bosh::Director::Config.trusted_certs = ''
      Bosh::Director::Config.max_threads = 1
      Bosh::Director::Config.event_log = Bosh::Director::EventLog::Log.new
    end

    private

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

    def sequel_model?(constant)
      constant.is_a?(Class) && constant.ancestors.include?(Sequel::Model)
    end

    def set_dataset_for(sequel_class, sequel_db)
      sequel_class.dataset = sequel_db[sequel_class.table_name]
    end

    def database_logger
      @database_logger ||= begin
                         name = "bosh-director-spec_helper-#{Process.pid}"
                         filename = File.join(BOSH_REPO_SRC_DIR, 'tmp', "#{name}.log")
                         FileUtils.mkdir_p(File.dirname(filename))
                         Logging::Logger.new(name).tap do |logger|
                           logger.add_appenders(
                             Logging.appenders.file(
                               "bosh-director-spec-logger-#{Process.pid}",
                               filename: filename,
                               layout: ThreadFormatter.layout,
                             ),
                           )
                           logger.level = :debug
                         end
                       end
    end

  end
end

SpecHelper.create_and_migrate_database

RSpec.configure do |config|
  config.include(FactoryBot::Syntax::Methods)
  config.include(CertificateHelpers)

  config.around(:each) do |example|
    SpecHelper.reset_database(SpecHelper.database, example)
  end

  config.before(:each) do
    SpecHelper.reset_director_config(SpecHelper.database, per_spec_logger)
  end
end

def gzip(string_to_gzip)
  StringIO.new.tap do |io|
    Zlib::GzipWriter.new(io).tap do |gz|
      gz.mtime = '1'
      gz.write(string_to_gzip)
      gz.close
    end
  end.string
end

def linted_rack_app(app)
  Rack::Builder.new do
    use Rack::Lint
    run app
  end
end
