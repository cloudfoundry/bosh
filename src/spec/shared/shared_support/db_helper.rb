module SharedSupport
  class DBHelper
    attr_reader :db_name, :username, :password, :port, :adapter, :host

    def self.build(db_options:)
      db_options.compact!

      db_type = db_options.delete(:type)

      case db_type
      when 'mysql'
        require 'shared_support/mysql'
        Mysql.new(db_options: db_options)
      when 'postgresql'
        require 'shared_support/postgresql'
        Postgresql.new(db_options: db_options)
      when 'sqlite'
        require 'shared_support/sqlite'
        Sqlite.new(db_options: db_options)
      else
        raise "Unsupported DB value: #{db_type}"
      end
    end

    private

    def initialize(db_options:)
      @adapter = db_options[:adapter]
      @db_name = db_options[:name]
      @username = db_options[:username]
      @password = db_options[:password]
      @host = db_options[:host]
      @port = db_options[:port]
    end

    def run_command(command, environment = {})
      IO.popen([environment, 'bash', '-c', command]).tap do |output|
        output.each_with_object('') do |line, collect|
          collect << line
          puts line.chomp
        end
        output.close
      end
    end
  end
end
