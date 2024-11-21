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
      run_command("sqlite3 #{@db_name} 'UPDATE sqlite_sequence SET seq = 0'")
    end

    private

    def create_db_file(db_name)
      @db_dir ||= Dir.mktmpdir

      File.join(@db_dir, "#{db_name}.sqlite")
    end
  end
end
