
module Bosh::Agent
  module Message
    class Apply
      def self.process(args)
        self.new(args).apply
      end
      def self.long_running?; true; end

      def initialize(args)
        @apply_spec = args.first
        @logger = Bosh::Agent::Config.logger
        @base_dir = Bosh::Agent::Config.base_dir
        @state_file = File.join(@base_dir, '/bosh/state.yml')
      end

      def apply
        @logger.info("Applying: #{@apply_spec.inspect}")
        @state = YAML.load_file(@state_file)

        if @state["deployment"].empty?
          @state["deployment"] = @apply_spec["deployment"]
          @state["resource_pool"] = @apply_spec['resource_pool']
          @state["networks"] = @apply_spec['networks']
          write_state
        end
        @state
      end

      def write_state
        # FIXME: use temporary file and move in place
        File.open(@state_file, 'w') do |f|
          f.puts(@state.to_yaml)
        end
      end

    end
  end
end
