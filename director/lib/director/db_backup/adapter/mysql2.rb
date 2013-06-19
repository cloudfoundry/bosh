require 'common/runs_commands'

module Bosh
  module Director
    module DbBackup
      module Adapter
        class Mysql2
          include Bosh::RunsCommands

          def initialize(db_config)
            @db_config = db_config
          end

          def export(output_path)
            cli_options = generate_cli_options(%w(user password host port))
            database_name = @db_config['database']
            sh "LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/var/vcap/packages/mysql/lib/mysql /var/vcap/packages/mysql/bin/mysqldump #{cli_options} #{database_name} > #{output_path}"
            output_path
          end

          private

          def generate_cli_options(params)
            params.map { |p| "--#{p}=#{@db_config[p]}"}.join " "
          end
        end
      end
    end
  end
end
