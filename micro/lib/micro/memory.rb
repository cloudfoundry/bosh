module VCAP
  module Micro
    class Memory

      attr_reader :current, :previous
      MEMORY = "/var/vcap/micro/config/memory"

      def initialize
        @logger = Console.logger
        @current = load_current
        @previous = load_previous
      end

      def load_previous(file=MEMORY)
        File.open(file) do |file|
          mem = file.read.split(/[#\s]+/).first.to_i
          if mem != 0
            @logger.info("loaded previous memory: #{mem}")
            return mem
          end
        end
        @logger.warn("unable to load previous memory")
        nil
      rescue => e
        @logger.error("previous memory failed #{file}: #{e.message}")
        @logger.error(e.backtrace.join("\n"))
        nil
      end

      def load_current
        free.split("\n").each do |line|
          tokens = line.split(/\s+/)
          if tokens[0].match(/^Mem:/)
            @logger.info("current memory: #{tokens[1]}")
            return tokens[1].to_i
          end
        end
        @logger.warn("unable to get current memory")
        nil
      rescue => e
        @logger.error("current memory failed: #{e.message}")
        @logger.error(e.backtrace.join("\n"))
        nil
      end

      def free
        `free -m 2> /dev/null`
      end

      # the fudge factor is needed as it is hard to get a conststent memory
      # reading from Linux, and we don't want to have the memory flap
      # displaying alerts to the user when the memory hasn't changed
      FUDGE_FACTOR = 5
      def changed?(current=@current, previous=@previous)
        previous && current && ((previous - current).abs > FUDGE_FACTOR)
      end

      def update_spec(max, spec_file=VCAP::Micro::Agent::APPLY_SPEC)
        spec = YAML.load_file(spec_file)
        props = spec['properties']
        props['dea']['max_memory'] = max
        props['cc']['admin_account_capacity']['memory']= max
        props['cc']['default_account_capacity']['memory'] = max/2
        spec
      end

      def save_spec(spec)
        File.open(VCAP::Micro::Agent::APPLY_SPEC, 'w') do |f|
          f.write(YAML.dump(spec))
        end
      end

      def update_previous
        @previous = @current
        File.open(MEMORY, "w") do |f|
          f.write @previous
        end
      end
    end
  end
end
