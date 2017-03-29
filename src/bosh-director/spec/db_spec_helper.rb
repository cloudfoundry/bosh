$: << File.expand_path('..', __FILE__)

require 'rspec'
require 'rspec/its'
require 'sequel'
require 'logging'
require_relative '../../bosh-director/lib/bosh/director/config'

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

      host = ENV['DB_HOST'] || '127.0.0.1'
      user = ENV['DB_USER']
      password = ENV['DB_PASSWORD']

      case ENV.fetch('DB', 'sqlite')
        when 'postgresql'
          require File.expand_path('../../bosh-dev/lib/bosh/dev/sandbox/postgresql', File.dirname(__FILE__))
          @db_helper = Bosh::Dev::Sandbox::Postgresql.new("#{@db_name}_director", init_logger, 5432, Bosh::Core::Shell.new, user || 'postgres', password || '', host)
        when 'mysql'
          require File.expand_path('../../bosh-dev/lib/bosh/dev/sandbox/mysql', File.dirname(__FILE__))
          @db_helper = Bosh::Dev::Sandbox::Mysql.new("#{@db_name}_dns", init_logger, Bosh::Core::Shell.new, user || 'root', password || 'password', host)
        when 'sqlite'
          require File.expand_path('../../bosh-dev/lib/bosh/dev/sandbox/sqlite', File.dirname(__FILE__))
          @db_helper = Bosh::Dev::Sandbox::Sqlite.new(File.join(@temp_dir, "#{@db_name}_director.sqlite"), init_logger)
        else
          raise "Unsupported DB value: #{ENV['DB']}"
      end

      @db_helper.create_db

      db_opts = {:max_connections => 32, :pool_timeout => 10}

      @db = Sequel.connect(@db_helper.connection_string, db_opts)
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

      FileUtils.rm_rf(@migration_dir) if @migration_dir
      @migration_dir = Dir.mktmpdir('migration-dir', @temp_dir)

      connect_database
    end

    def migrate_all_before(migration_file)
      reset_database
      migration_file_full_path = File.join(@director_migrations_dir, migration_file)
      files_to_migrate = Dir.glob("#{@director_migrations_dir}/*").sort.select do |filename|
        filename < migration_file_full_path
      end

      FileUtils.cp_r(files_to_migrate, @migration_dir)
      Sequel::TimestampMigrator.new(@db, @migration_dir, {}).run
    end

    def migrate(migration_file)
      migration_file_full_path = File.join(@director_migrations_dir, migration_file)
      FileUtils.cp(migration_file_full_path, @migration_dir)
      Sequel::TimestampMigrator.new(@db, @migration_dir, {}).run
    end

    def get_latest_migration_script
      Dir.entries(@director_migrations_dir).select {|f| !File.directory? f}.sort.last
    end

    def get_migrations
      Dir.glob(File.join(@director_migrations_dir, '..', '**', '[0-9]*_*.rb'))
    end
  end
end

DBSpecHelper.init

RSpec.configure do |rspec|
  rspec.after(:suite) do
    DBSpecHelper.disconnect_database
  end
end
