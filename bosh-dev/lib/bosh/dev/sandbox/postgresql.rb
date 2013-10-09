require 'bosh/dev'
require 'bosh/core/shell'

module Bosh::Dev::Sandbox
  class Postgresql
    attr_reader :directory

    def initialize(directory, db_name, logger, runner = Bosh::Core::Shell.new)
      @directory = directory
      @db_name = db_name
      @logger = logger
      @runner = runner
    end

    def create_db
      @logger.info("Creating database #{db_name}")
      runner.run(%Q{psql -c 'create database "#{db_name}";' > /dev/null})
    end

    def drop_db
      @logger.info("Dropping database #{db_name}")
      runner.run(%Q{psql -c 'drop database "#{db_name}";' > /dev/null})
    end

    private

    attr_reader :db_name, :runner
  end
end
