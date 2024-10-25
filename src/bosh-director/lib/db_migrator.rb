require 'sequel'

class DBMigrator
  MAX_MIGRATION_ATTEMPTS = 50
  MIGRATIONS_DIR = File.expand_path('../../db/migrations/director', __FILE__)

  Sequel.extension :migration

  def initialize(database, options = {}, retry_interval = 0.5)
    return unless database && File.directory?(MIGRATIONS_DIR)

    @migrator = Sequel::TimestampMigrator.new(database, MIGRATIONS_DIR, options)
    @database = database
    @options = options
    @retry_interval = retry_interval
  end

  def current?
    @migrator.is_current?
  end

  def migrate
    @migrator.run
  end

  def finished?
    tries = 0
    until current?
      tries += 1
      sleep @retry_interval
      return false if tries >= MAX_MIGRATION_ATTEMPTS
    end
    true
  end
end
