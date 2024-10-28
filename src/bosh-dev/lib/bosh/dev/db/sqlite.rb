require 'bosh/dev'

module Bosh::Dev::DB
  class Sqlite
    attr_reader :db_name, :username, :password, :port, :adapter, :host

    def initialize(db_options:)
      @adapter = 'sqlite'
      @db_name = create_db_file(db_options[:name])

      @username = db_options.fetch(:username, nil)
      @password = db_options.fetch(:password, nil)
      @host = db_options.fetch(:host, 'localhost')
      @port = db_options.fetch(:port, nil)
    end

    def connection_string
      "sqlite://#{@db_name}"
    end

    def create_db
    end

    def drop_db
      DBHelper.run_command("rm #{@db_name}")
    end

    def current_tasks
      raise '"#current_tasks" not supported for sqlite'
    end

    def current_locked_jobs
      raise '"#current_locked_jobs" not supported for sqlite'
    end

    def truncate_db
      DBHelper.run_command("sqlite3 #{@db_name} 'UPDATE sqlite_sequence SET seq = 0'")
    end

    private

    def create_db_file(db_name)
      @db_dir ||= Dir.mktmpdir

      File.join(@db_dir, "#{db_name}.sqlite")
    end
  end
end
