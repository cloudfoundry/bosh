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

          @old_spec = Bosh::Agent::Message::State.new(nil).state
        end
      end

      def drain
        case @drain_type
        when "shutdown"
          return 0
        when "update"
          # HACK: We go through the motions below to be able to support drain scripts written as shell scripts
          if @old_spec.key?('job') && drain_script_exists?
            ENV['BOSH_CURRENT_STATE'] = Yajl::Encoder.encode(@old_spec)
            ENV['BOSH_APPLY_SPEC'] = Yajl::Encoder.encode(@spec)

            job_change =  if !@old_spec.key?('job')
                            "job_new"
                          elsif @old_spec['job']['sha1'] == @spec['job']['sha1']
                            p @spec
                            "job_unchanged"
                          else
                            "job_changed"
                          end

            hash_change = if !@old_spec.key?('configuration_hash')
                            "hash_new"
                          elsif @old_spec['configuration_hash'] == @spec['configuration_hash']
                            "hash_unchanged"
                          else
                            "hash_changed"
                          end

            drain_time = run_drain_script(job_change, hash_change, updated_packages.flatten)
            return drain_time
          end
          return 0
        else
          raise Bosh::Agent::MessageHandlerError,
            "Unknown drain type #{@drain_type}"
        end
      end

      def run_drain_script(job_updated, hash_updated, updated_packages)
        # Drain contract: on success the drain script should return a number exit(0)
        child = POSIX::Spawn::Child.new(drain_script, job_updated, hash_updated, *updated_packages)
        result = child.out
        unless result.match(/\A\d+\Z/) && child.status.exitstatus == 0
          raise Bosh::Agent::MessageHandlerError,
            "Drain script exit #{child.status.exitstatus}: #{result}"
        end
        return result.to_i
      end

      def updated_packages
        updated_packages = []

        return updated_packages unless @old_spec.key?('packages')

        # Check old packages
        updated_packages << @old_spec['packages'].find_all do |pkg_name, pkg|
          if @spec['packages'].key?(pkg_name)
            pkg['sha1'] != @spec['packages'][pkg_name]['sha1']
          else
            false
          end
        end.collect { |package_name, pkg| package_name }

        # New packages counts as new
        updated_packages << @spec['packages'].find_all do |pkg_name, pkg|
          unless @old_spec['packages'].key?(pkg_name)
            true
          else
            false
          end
        end.collect { |package_name, pkg| package_name } 
      end

      def drain_script
         job_name = @old_spec['job']['name']
        "#{@base_dir}/jobs/#{job_name}/bin/drain"
      end

      def drain_script_exists?
        File.exists?(drain_script)
      end

    end
  end
end
