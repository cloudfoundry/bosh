require 'sequel'

class DBMigrator
  DEFAULT_RETRY_INTERVAL = 0.5
  MAX_MIGRATION_ATTEMPTS = 50
  MIGRATIONS_DIR = File.expand_path('../../db/migrations/director', __FILE__)

  class MigrationsNotCurrentError < RuntimeError; end

  def initialize(database, options = {}, retry_interval = DEFAULT_RETRY_INTERVAL)
    return unless database && File.directory?(MIGRATIONS_DIR)

    Sequel.extension :migration, :core_extensions

    @database = database
    @options = options
    @retry_interval = retry_interval
  end

  def current?
    Sequel::Migrator.is_current?(@database, MIGRATIONS_DIR)
  end

  def migrate
    Sequel::Migrator.run(@database, MIGRATIONS_DIR, @options)
  end

  def ensure_migrated!
    finished? ||
      raise(MigrationsNotCurrentError.new("Migrations not current after #{MAX_MIGRATION_ATTEMPTS} retries"))
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
