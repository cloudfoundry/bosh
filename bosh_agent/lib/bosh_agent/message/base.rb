# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  module Message
    class Base

      def logger
        Bosh::Agent::Config.logger
      end

      def base_dir
        Bosh::Agent::Config.base_dir
      end

      def logs_dir
        File.join(base_dir, "sys", "log")
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

      def handler_error(message)
        logger.error("Handler error: #{message}")
        raise Bosh::Agent::MessageHandlerError, message
      end

    end
  end
end
