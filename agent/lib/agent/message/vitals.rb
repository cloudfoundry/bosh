# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  module Message
    class Vitals < Base

      def self.process(args)
        self.new.vitals
      end

      def vitals
        response = Bosh::Agent::Config.state.to_hash

        logger.info("Agent vitals: #{response.inspect}")

        response["job_state"] = Bosh::Agent::Monit.service_group_state
        response["vitals"] = Bosh::Agent::Monit.get_vitals
        response["vitals"]["disk"] = Bosh::Agent::Message::DiskUtil.get_usage

        response
      rescue Bosh::Agent::StateError => e
        raise Bosh::Agent::MessageHandlerError, e
      end
    end
  end
end