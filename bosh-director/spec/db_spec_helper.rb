$: << File.expand_path('..', __FILE__)

require 'rspec'
require 'rspec/its'
require 'sequel'
require_relative '../../bosh-director/lib/bosh/director/config'

module DBSpecHelper
  class << self
    attr_reader :db

    def init
      @temp_dir = Bosh::Director::Config.generate_temp_dir
      @director_migrations_dir = File.expand_path('../../db/migrations/director', __FILE__)

     Sequel.extension :migration
    end

    def connect_database
      db_path = ENV['DB_CONNECTION'] || "sqlite://#{File.join(@db_dir, 'director.db')}"
      db_opts = {:max_connections => 32, :pool_timeout => 10}

      @db = Sequel.connect(db_path, db_opts)
    end

    def reset_database
      if @db
        @db.disconnect
        @db = nil
      end

      FileUtils.rm_rf(@db_dir) if @db_dir
      @db_dir = Dir.mktmpdir(nil, @temp_dir)

      FileUtils.rm_rf(@migration_dir) if @migration_dir
      @migration_dir = Dir.mktmpdir('migration-dir', @temp_dir)

      connect_database
    end

    def migrate_all_before(migration_file)
      reset_database
      migration_file_full_path = File.join(@director_migrations_dir, migration_file)
      files_to_migrate = Dir.glob("#{@director_migrations_dir}/*").select do |filename|
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
  end
end

DBSpecHelper.init
