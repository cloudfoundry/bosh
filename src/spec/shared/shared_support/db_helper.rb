module SharedSupport
  class DBHelper
    MYSQL = 'mysql'
    POSTGRESQL = 'postgresql'
    SQLITE = 'sqlite3'
    DB_TYPES = [MYSQL, POSTGRESQL, SQLITE].freeze

    def self.run_command(command, environment = {})
      io = IO.popen([environment, 'bash', '-c', command])

      lines =
        io.each_with_object("") do |line, collect|
          collect << line
          puts line.chomp
        end

      io.close

      lines
    end

    def self.build(db_options:)
      db_options.compact!

      db_type = db_options.delete(:type)

      db_handler = # TODO: use sub-class here instead of delegating everything to @db_handler
        case db_type
        when 'mysql'
          require 'shared_support/mysql'
          SharedSupport::Mysql.new(db_options: db_options)
        when 'postgresql'
          require 'shared_support/postgresql'
          SharedSupport::Postgresql.new(db_options: db_options)
        when 'sqlite'
          require 'shared_support/sqlite'
          SharedSupport::Sqlite.new(db_options: db_options)
        else
          raise "Unsupported DB value: #{db_type}"
        end

      new(db_handler)
    end

    def db_name
      @db_handler.db_name
    end

    def username
      @db_handler.username
    end

    def password
      @db_handler.password
    end

    def adapter
      @db_handler.adapter
    end

    def port
      @db_handler.port
    end

    def host
      @db_handler.host
    end

    def connection_string
      @db_handler.connection_string
    end

    def create_db
      @db_handler.create_db
    end

    def drop_db
      @db_handler.drop_db
    end

    def current_tasks
      @db_handler.current_tasks
    end

    def current_locked_jobs
      @db_handler.current_locked_jobs
    end

    def truncate_db
      @db_handler.truncate_db
    end

    private

    def initialize(db_handler)
      @db_handler = db_handler
    end
  end
end
