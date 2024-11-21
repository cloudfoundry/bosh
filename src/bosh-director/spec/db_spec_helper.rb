BOSH_REPO_SRC = File.expand_path(File.join('..', '..', '..'), __FILE__)

BOSH_DIRECTOR_ROOT = File.join(BOSH_REPO_SRC, 'bosh-director')

$LOAD_PATH << File.join(BOSH_DIRECTOR_ROOT, 'lib')

require 'rspec'
require 'sequel'
require 'securerandom'

require 'bosh/director/config'

require 'db_migrator'

module DBSpecHelper
  class << self
    attr_reader :db

    def connect_database
      db_options = {
        type: ENV.fetch('DB', 'sqlite'),
        name: ['director_test', SecureRandom.uuid.delete('-')].join('_'),
        username: ENV['DB_USER'],
        password: ENV['DB_PASSWORD'],
        host: ENV['DB_HOST'],
        port: ENV['DB_PORT'],
      }

      @db_helper =
        SharedSupport::DBHelper.build(db_options: db_options)


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

    private

    def migrate_to_version(version)
      DBMigrator.new(@db, target: version).migrate
    end
  end
end

RSpec.configure do |rspec|
  rspec.after(:suite) do
    DBSpecHelper.disconnect_database
  end
end
