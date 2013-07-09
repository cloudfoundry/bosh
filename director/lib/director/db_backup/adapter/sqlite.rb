module Bosh
  module Director
    module DbBackup
      module Adapter
        class Sqlite
          def initialize(db_config)
            @db_config = db_config
          end

          def export(output_path)
            FileUtils.cp(@db_config.fetch('database'), output_path)
          end
        end
      end
    end
  end
end