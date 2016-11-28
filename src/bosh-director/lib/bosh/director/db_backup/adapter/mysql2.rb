require 'open3'

module Bosh
  module Director
    module DbBackup
      module Adapter
        class Mysql2
          def initialize(db_config)
            @db_config = db_config
          end

          def export(path)
            out, err, status = Open3.capture3({'MYSQL_PWD' => @db_config.fetch('password')},
                                              'mysqldump',
                                              '--user',        @db_config.fetch('user'),
                                              '--host',        @db_config.fetch('host'),
                                              '--port',        @db_config.fetch('port').to_s,
                                              '--result-file', path,
                                              @db_config.fetch('database'))
            raise("mysqldump exited #{status.exitstatus}, output: '#{out}', error: '#{err}'") unless status.success?
            path
          end
        end
      end
    end
  end
end
