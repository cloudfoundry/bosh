module Bosh::Agent
  module Message
    class Base

      def logger
        Bosh::Agent::Config.logger
      end

      def base_dir
        Bosh::Agent::Config.base_dir
      end

      def settings
        Bosh::Agent::Config.settings
      end

      def store_path
        File.join(base_dir, 'store')
      end

      def store_migration_target
        File.join(base_dir, 'store_migraton_target')
      end

    end
  end
end
