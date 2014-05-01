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
        output = `bin/bosh-director-migrate -c #{@director_config_path}`
        unless $?.exitstatus == 0
          @logger.info("Failed to run migrations: \n#{output}")
          exit 1
        end
      end
    end
  end
end
