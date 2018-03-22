require 'sequel'

class DBMigrator
  def initialize(database, type, options = {})
    @migrator = case type
                when :cpi then cpi_migrator(database, options)
                when :director then director_migrator(database, options)
                when :dns then dns_migrator(database, options)
                end
  end

  def current?
    @migrator&.is_current?
  end

  def migrate
    @migrator&.run
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
