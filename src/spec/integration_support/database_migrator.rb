require 'open3'

module IntegrationSupport
  class DatabaseMigrator
    def initialize(director_dir, director_config_path, logger)
      @director_dir = director_dir
      @director_config_path = director_config_path
      @logger = logger
    end

    def migrate
      @logger.info("Migrating database with #{@director_config_path}")

      Dir.chdir(@director_dir) do
        Open3.popen3("bin/bosh-director-migrate -c #{@director_config_path}") do |_stdin, _stdout, stderr, thread|
          unless thread.value.exitstatus == 0
            migration_error = stderr.read
            @logger.info("Failed to run migrations: \n #{migration_error}")
            raise "Failed to run migrations: #{migration_error}"
          end
        end
      end
    end
  end
end
