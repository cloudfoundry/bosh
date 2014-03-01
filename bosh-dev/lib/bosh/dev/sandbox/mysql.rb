require 'bosh/dev'
require 'bosh/core/shell'

module Bosh::Dev::Sandbox
  class Mysql
    attr_reader :db_name, :username, :password, :adapter, :port

    # rubocop:disable ParameterLists
    def initialize(db_name, logger, runner = Bosh::Core::Shell.new, username, password)
    # rubocop:enable ParameterLists
      @db_name = db_name
      @logger = logger
      @runner = runner
      @username = username
      @password = password
      @adapter = 'mysql2'
      @port = 3306
    end

    def create_db
      @logger.info("Creating mysql database #{db_name}")
      @runner.run(%Q{mysql --user=#{@username} --password=#{@password} -e 'create database `#{db_name}`;' > /dev/null 2>&1})
    end

    def drop_db
      @logger.info("Dropping mysql database #{db_name}")
      @runner.run(%Q{mysql --user=#{@username} --password=#{@password} -e 'drop database `#{db_name}`;' > /dev/null 2>&1})
    end
  end
end
