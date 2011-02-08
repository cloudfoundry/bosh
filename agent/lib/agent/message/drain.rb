require 'yaml'

module Bosh::Agent
  module Message
    class Drain
      def self.process(args)
        self.new(args).drain
      end

      def initialize(args)
        @logger = Bosh::Agent::Config.logger
        @base_dir = Bosh::Agent::Config.base_dir

        @logger.info("Draining: #{args.inspect}")

        @drain_type = args.shift

        if @drain_type == "update"
          @spec = args.shift
          unless @spec
            raise Bosh::Agent::MessageHandlerError,
              "Drain update called without apply spec"
          end
        end
      end

      def drain
        case @drain_type
        when "shutdown"
          return 1
        when "update"
          return 2
        else
          raise Bosh::Agent::MessageHandlerError,
            "Unknown drain type #{@drain_type}"
        end
      end

    end
  end
end
