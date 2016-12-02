module Bosh::Monitor
  module Plugins
    class Nats < Base
      SUBJECT = "bosh.hm.events"

      def validate_options
        options.kind_of?(Hash) &&
          options["endpoint"] &&
          options.has_key?("user") &&
          options.has_key?("password")
      end

      def run
        unless EM.reactor_running?
          logger.error("NATS delivery agent can only be started when event loop is running")
          return false
        end

        nats_client_options = {
          :uri       => options["endpoint"],
          :user      => options["user"],
          :pass      => options["password"],
          :autostart => false
        }

        @nats = NATS.connect(nats_client_options) do
          logger.info("Ready to publish alerts to NATS at '#{options["endpoint"]}'")
        end
      end

      def process(event)
        if @nats.nil?
          @logger.error("Cannot deliver event, NATS not initialized")
          return false
        end

        nats_subject = options["subject"] || SUBJECT
        EM.schedule do
          @nats.publish(nats_subject, event.to_json)
        end
        true
      end
    end
  end
end
