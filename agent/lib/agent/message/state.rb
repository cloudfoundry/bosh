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
        response

      rescue Bosh::Agent::StateError => e
        raise Bosh::Agent::MessageHandlerError, e
      end

      def job_state
        unless Bosh::Agent::Monit.enabled
          return "running"
        end

        client = Bosh::Agent::Monit.monit_api_client

        status = client.status(:group => BOSH_APP_GROUP)
        not_running = status.reject do |name, data|
          # break early if any service is initializing
          return "starting" if data[:monitor] == :init

          # at least with monit_api a stopped services is still running
          (data[:monitor] == :yes && data[:status][:message] == "running")
        end
        not_running.empty? ? "running" : "failing"
      end

    end
  end
end
