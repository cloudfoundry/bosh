$: << File.expand_path('..', __FILE__)

require 'rspec'
require 'rspec/its'
require 'sequel'
require 'logging'
require 'securerandom'

require_relative '../../bosh-director/lib/bosh/director/config'
require_relative '../../bosh-director/lib/db_migrator'

module DBSpecHelper
  class << self
    attr_reader :db, :director_migrations_dir

    def init
      @temp_dir = Bosh::Director::Config.generate_temp_dir
      @director_migrations_dir = File.expand_path('../../db/migrations/director', __FILE__)

      Sequel.extension :migration
    end

    def connect_database
      @db_name = SecureRandom.uuid.gsub('-', '')
      init_logger = Logging::Logger.new('TestLogger')

      db_options = {
        username: ENV['DB_USER'],
        password: ENV['DB_PASSWORD'],
        host: ENV['DB_HOST'] || '127.0.0.1',
      }.compact

      case ENV.fetch('DB', 'sqlite')
        when 'postgresql'
          require File.expand_path('../../bosh-dev/lib/bosh/dev/sandbox/postgresql', File.dirname(__FILE__))
          db_options[:port] = 5432

          @db_helper = Bosh::Dev::Sandbox::Postgresql.new("#{@db_name}_director", Bosh::Core::Shell.new, init_logger, db_options)
        when 'mysql'
          require File.expand_path('../../bosh-dev/lib/bosh/dev/sandbox/mysql', File.dirname(__FILE__))
          db_options[:port] = 3306

          @db_helper = Bosh::Dev::Sandbox::Mysql.new("#{@db_name}_dns", Bosh::Core::Shell.new, init_logger, db_options)
        when 'sqlite'
          require File.expand_path('../../bosh-dev/lib/bosh/dev/sandbox/sqlite', File.dirname(__FILE__))
          @db_helper = Bosh::Dev::Sandbox::Sqlite.new(File.join(@temp_dir, "#{@db_name}_director.sqlite"), init_logger)
        else
          raise "Unsupported DB value: #{ENV['DB']}"
      end

      @db_helper.create_db

      Sequel.default_timezone = :utc
      @db = Sequel.connect(@db_helper.connection_string, {:max_connections => 32, :pool_timeout => 10})
    end

    def disconnect_database
      if @db
        @db.disconnect
        @db_helper.drop_db

        @db = nil
        @db_helper = nil
      end
    end

    def reset_database
      disconnect_database
      connect_database
    end

    def migrate_all_before(migration_file)
      reset_database
      version = migration_file.split('_').first.to_i
      migrate_to_version(version - 1)
    end

    def migrate(migration_file)
      version = migration_file.split('_').first.to_i
      migrate_to_version(version)
    end

    def get_latest_migration_script
      Dir.entries(@director_migrations_dir).select {|f| !File.directory? f}.sort.last
    end

    def get_migrations
      Dir.glob(File.join(@director_migrations_dir, '..', '**', '[0-9]*_*.rb'))
    end

    private

    def migrate_to_version(version)
      DBMigrator.new(@db, :director, target: version).migrate
    end
  end
end

DBSpecHelper.init

RSpec.configure do |rspec|
  rspec.after(:suite) do
    DBSpecHelper.disconnect_database
  end
end
