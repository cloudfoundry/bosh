require 'bosh/dev'
require 'bosh/core/shell'

module Bosh::Dev::Sandbox
  class Postgresql
    attr_reader :db_name, :username, :password, :adapter, :port

    def initialize(db_name, logger, runner = Bosh::Core::Shell.new)
      @db_name = db_name
      @logger = logger
      @runner = runner
      @username = 'postgres'
      @password = ''
      @adapter = 'postgres'
      @port = 5432
    end

    # Assumption is that user running tests can
    # login via psql without entering password.
    def create_db
      @logger.info("Creating postgres database #{db_name}")
      @runner.run(%Q{psql -U postgres -c 'create database "#{db_name}";' > /dev/null})
    end

    def drop_db
      @logger.info("Dropping postgres database #{db_name}")
      @runner.run(%Q{psql -U postgres -c 'drop database "#{db_name}";' > /dev/null})
    end
  end
end
