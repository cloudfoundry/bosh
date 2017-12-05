require 'bosh/dev'

module Bosh::Dev::Sandbox
  class DatabaseMigrator
    def initialize(director_dir, director_config_path, logger)
      @director_dir = director_dir
      @director_config_path = director_config_path
      @logger = logger
    end

    def migrate
      @logger.info("Migrating database with #{@director_config_path}")

      Dir.chdir(@director_dir) do
        Open3.popen3("bin/bosh-director-migrate -c #{@director_config_path}") do |stdin, stdout, stderr, thread|
          unless thread.value.exitstatus == 0
            @logger.info("Failed to run migrations: \n #{stderr.read}")
            raise "Failed to run migrations: \n #{stderr.read}"
          end
        end
      end
    end
  end
end
