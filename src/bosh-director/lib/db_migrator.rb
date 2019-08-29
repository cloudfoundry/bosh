require 'sequel'

class DBMigrator
  MAX_MIGRATION_ATTEMPTS = 50

  def initialize(database, type, options = {}, retry_interval = 0.5)
    @migrator = case type
                when :cpi then method(:cpi_migrator)
                when :director then method(:director_migrator)
                when :dns then method(:dns_migrator)
                end

    @database = database
    @options = options
    @retry_interval = retry_interval
  end

  def current?
    @migrator.call(@database, @options)&.is_current?
  end

  def migrate
    @migrator.call(@database, @options)&.run
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

  private

  def migrator(database, directory, options)
    return unless database && directory && File.directory?(directory)

    Sequel.extension :migration
    Sequel::TimestampMigrator.new(database, directory, options)
  end

  def cpi_migrator(database, options)
    cpi = options.delete(:cpi)
    return if cpi.nil?

    require_path = File.join('cloud', cpi)
    cpi_path = $LOAD_PATH.find { |p| File.exist?(File.join(p, require_path)) }

    options[:table] ||= "#{cpi}_cpi_schema"
    directory = File.expand_path('../db/migrations', cpi_path)
    migrator(database, directory, options)
  end

  def director_migrator(database, options)
    directory = File.expand_path('../../db/migrations/director', __FILE__)
    migrator(database, directory, options)
  end

  def dns_migrator(database, options)
    options[:table] ||= 'dns_schema'
    directory = File.expand_path('../../db/migrations/dns', __FILE__)
    migrator(database, directory, options)
  end
end
