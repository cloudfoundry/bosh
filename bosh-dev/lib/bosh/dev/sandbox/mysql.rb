require 'bosh/dev'
require 'bosh/core/shell'

module Bosh::Dev::Sandbox
  class Mysql
    attr_reader :db_name, :directory, :username, :password, :adapter, :port

    # rubocop:disable ParameterLists
    def initialize(directory, db_name, logger, runner = Bosh::Core::Shell.new, username, password)
    # rubocop:enable ParameterLists
      @directory = directory
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
      runner.run(%Q{mysql --user=#{@username} --password=#{@password} -e 'create database `#{db_name}`;' > /dev/null 2>&1})
    end

    def drop_db
      @logger.info("Dropping mysql database #{db_name}")
      runner.run(%Q{mysql --user=#{@username} --password=#{@password} -e 'drop database `#{db_name}`;' > /dev/null 2>&1})
    end

    private

    attr_reader :runner
  end
end
