# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  module Message
    class State < Base

      def self.process(args)
        self.new.state
      end

      def state
        response = Bosh::Agent::Config.state.to_hash

        logger.info("Agent state: #{response.inspect}")

        if settings
          response["agent_id"] = settings["agent_id"]
          response["vm"] = settings["vm"]
        end

        response["job_state"] = job_state
        response["bosh_protocol"] = Bosh::Agent::BOSH_PROTOCOL
        response["ntp"] = Bosh::Agent::NTP.offset

        response

      rescue Bosh::Agent::StateError => e
        raise Bosh::Agent::MessageHandlerError, e
      end

      def job_state
        Bosh::Agent::Monit.service_group_state
      end
    end
  end
end
