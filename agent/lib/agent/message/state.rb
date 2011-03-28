require 'yaml'

module Bosh::Agent
  module Message
    class State
      def self.process(args)
        self.new(args).state
      end

      def initialize(args)
        @logger = Bosh::Agent::Config.logger
        @base_dir = Bosh::Agent::Config.base_dir
      end

      def state
        state_file = File.join(@base_dir, 'bosh', 'state.yml')
        if File.exist?(state_file)
          state = YAML.load_file(state_file)
        else
          state = {
           "deployment"=>"",
           "networks"=>{},
           "resource_pool"=>{}
          }
          File.open(state_file, 'w') do |f|
            f.puts(state.to_yaml)
          end
        end
        @logger.info("Agent state: #{state.inspect}")

        settings = Bosh::Agent::Config.settings
        if settings
          state["agent_id"] = settings["agent_id"]
          state["vm"] = settings["vm"]
        end

        state["job_state"] = job_state
        state
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
