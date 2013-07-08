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
            username = @db_config.fetch('user')
            password = @db_config.fetch('password')
            host = @db_config.fetch('host')
            port = @db_config.fetch('port')
            database = @db_config.fetch('database')
            sh "PGPASSWORD=#{password} /var/vcap/packages/postgres/bin/pg_dump --host #{host} --port #{port} --username=#{username} #{database} > #{path}"
            path
          end
        end
      end
    end
  end
end
