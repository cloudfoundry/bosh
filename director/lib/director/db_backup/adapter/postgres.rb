require 'common/runs_commands'

module Bosh
  module Director
    module DbBackup
      module Adapter
        class Postgres
          include Bosh::RunsCommands

          def initialize(db_config)
            @db_config = db_config
          end

          def export(path)
            sh "PGPASSWORD=#{@db_config['password']} /var/vcap/packages/postgres/bin/pg_dump --username=#{@db_config['user']} #{@db_config['database']} > #{path}"
            path
          end
        end
      end
    end
  end
end
