require 'riemann/client'

module Bosh::Monitor
  module Plugins
    class Riemann < Base
      def run
        unless EM.reactor_running?
          logger.error("Riemann plugin can only be started when event loop is running")
          return false
        end

        logger.info("Riemann delivery agent is running...")
        return true
      end

      def validate_options
       !!(options.kind_of?(Hash) && options["host"] && options["port"])
      end

      def client
        @client ||= ::Riemann::Client.new host: options["host"], port: options["port"]
        return @client
      end

      def process(event)
        client << {
          :id           => event.id,
          :service      => "bosh.hm",
          :description  => event.short_description,
          :details      => event.to_hash
        }
      rescue => e
        logger.error("Error sending riemann event: #{e}")
      end
    end
  end
end
