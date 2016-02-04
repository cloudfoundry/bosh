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
            env = {}
            env['PGPASSWORD'] = @db_config['password'] if @db_config.has_key?('password')

            stdout, stderr, status = Open3.capture3(
              env,
              'pg_dump',
              '--clean',
              '--host',     @db_config.fetch('host'),
              '--port',     @db_config.fetch('port').to_s,
              '--username', @db_config.fetch('user'),
              '--file',     path,
              @db_config.fetch('database'),
            )

            unless status.success?
              raise("pg_dump exited #{status.exitstatus}, output: '#{stdout}', error: '#{stderr}'")
            end

            path
          end
        end
      end
    end
  end
end
