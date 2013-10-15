require 'open3'

module Bosh
  module Director
    module DbBackup
      module Adapter
        class Postgres

          def initialize(db_config)
            @db_config = db_config
          end

          def export(path)
            out, err, status = Open3.capture3({'PGPASSWORD' => @db_config.fetch('password')},
                    'pg_dump',
                    '--host', @db_config.fetch('host'),
                    '--port', @db_config.fetch('port').to_s,
                    '--username', @db_config.fetch('user'),
                    '--file', path,
                    @db_config.fetch('database'))

            raise("pg_dump exited #{status.exitstatus}, output: '#{out}', error: '#{err}'") unless status.success?
            path
          end
        end
      end
    end
  end
end
