require 'bosh/dev'

module Bosh::Dev::Sandbox
  class DatabaseMigrator
    def initialize(director_dir, director_config_path)
      @director_dir = director_dir
      @director_config_path = director_config_path
    end

    def migrate
      Dir.chdir(@director_dir) do
        output = `bin/bosh-director-migrate -c #{@director_config_path}`
        unless $?.exitstatus == 0
          puts "Failed to run migration:"
          puts output
          exit 1
        end
      end
    end
  end
end
