require 'bosh/director/db_backup/adapter'
require 'bosh/director/db_backup/error'

module Bosh
  module Director
    module DbBackup
      def self.create(db_config)
        adapter_to_module(db_config['adapter']).new(db_config)
      end

      def self.adapter_to_module(adapter)
        adapter_module = adapter.capitalize

        if Adapter.const_defined?(adapter_module)
          Adapter.const_get adapter_module
        else
          raise Adapter::Error.new("backup for database adapter #{adapter} (module #{adapter_module}) is not implemented")
        end
      end
    end
  end
end
