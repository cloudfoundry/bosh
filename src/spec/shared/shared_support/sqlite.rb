require 'shellwords'

module SharedSupport
  class Sqlite < SharedSupport::DBHelper
    TYPE = 'sqlite3'
    DEFAULTS = {
      adapter: 'sqlite',
      username: nil,
      password: nil,
      host: 'localhost',
      port: nil
    }

    def initialize(db_options:)
      super(
        db_options: DEFAULTS.merge(db_options)
                            .merge(name: create_db_file(db_options[:name]))
      )
    end

    def connection_string
      "sqlite://#{@db_name}"
    end

    def create_db
    end

    def drop_db
      run_command("rm #{@db_name}")
    end

    def current_tasks
      raise '"#current_tasks" not supported for sqlite'
    end

    def current_locked_jobs
      raise '"#current_locked_jobs" not supported for sqlite'
    end

    def truncate_db
      db = Shellwords.escape(@db_name)
      # Fetch user tables and check for sqlite_sequence in one query so we can
      # conditionally reset auto-increment counters only when the table exists.
      # sqlite_sequence is only present when at least one table uses AUTOINCREMENT.
      raw = %x{sqlite3 #{db} "SELECT name FROM sqlite_master WHERE type='table' AND name <> 'schema_migrations';"}.strip
      all_tables = raw.split("\n").map(&:strip).reject(&:empty?)

      user_tables = all_tables.reject { |t| t == 'sqlite_sequence' }
      return if user_tables.empty?

      sql_parts = ["PRAGMA foreign_keys=OFF"]
      sql_parts += user_tables.map { |t| "DELETE FROM \"#{t}\"" }
      sql_parts << "DELETE FROM sqlite_sequence" if all_tables.include?('sqlite_sequence')

      run_command("sqlite3 #{db} #{Shellwords.escape(sql_parts.join('; ') + ';')}")
    end

    private

    def create_db_file(db_name)
      @db_dir ||= Dir.mktmpdir

      File.join(@db_dir, "#{db_name}.sqlite")
    end
  end
end
