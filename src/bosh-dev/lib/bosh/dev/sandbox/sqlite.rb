require 'bosh/dev'
require 'bosh/dev/shell'

module Bosh::Dev::Sandbox
  class Sqlite
    attr_reader :db_name, :username, :password, :port, :adapter, :host

    def initialize(db_name, logger, options = {}, runner = Bosh::Dev::Shell.new)
      @adapter = 'sqlite'
      @db_name = create_db_file(db_name)
      @logger = logger
      @runner = runner

      @username = options.fetch(:username, nil)
      @password = options.fetch(:password, nil)
      @host = options.fetch(:host, 'localhost')
      @port = options.fetch(:port, nil)
    end

    def connection_string
      "sqlite://#{@db_name}"
    end

    def ca_path
      raise '"#ca_path" not supported for sqlite'
    end

    def create_db
      @logger.info("Creating sqlite database #{@db_name}")
    end

    def drop_db
      @logger.info("Dropping sqlite database #{@db_name}")
      @runner.run("rm #{@db_name}")
    end

    def load_db_initial_state(_initial_state_assets_dir)
      raise '"#load_db_initial_state" not supported for sqlite'
    end

    def load_db(_dump_file_path)
      raise '"#load_db" not supported for sqlite'
    end

    def current_tasks
      raise '"#current_tasks" not supported for sqlite'
    end

    def current_locked_jobs
      raise '"#current_locked_jobs" not supported for sqlite'
    end

    def truncate_db
      @logger.info("Truncating sqlite database #{@db_name}")
      @runner.run("sqlite3 #{@db_name} 'UPDATE sqlite_sequence SET seq = 0'")
    end

    private

    def create_db_file(db_name)
      @db_dir ||= Dir.mktmpdir

      File.join(@db_dir, "#{db_name}.sqlite")
    end
  end
end
