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
        state
      end

    end
  end
end
