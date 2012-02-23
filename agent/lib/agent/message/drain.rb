require 'yaml'
require 'monitor'

module Bosh::Agent
  module Message
    class Drain

      HM_NOTIFY_TIMEOUT = 5

      def self.process(args)
        self.new(args).drain
      end

      def initialize(args)
        @logger     = Bosh::Agent::Config.logger
        @base_dir   = Bosh::Agent::Config.base_dir
        @nats       = Bosh::Agent::Config.nats
        @agent_id   = Bosh::Agent::Config.agent_id
        @old_spec   = Bosh::Agent::Config.state.to_hash
        @args       = args

        @drain_type = args[0]
        @spec       = args[1]
      end

      def job_change
        if !@old_spec.key?('job')
          "job_new"
        elsif @old_spec['job']['sha1'] == @spec['job']['sha1']
          "job_unchanged"
        else
          "job_changed"
        end
      end

      def hash_change
        if !@old_spec.key?('configuration_hash')
          "hash_new"
        elsif @old_spec['configuration_hash'] == @spec['configuration_hash']
          "hash_unchanged"
        else
          "hash_changed"
        end
      end

      def drain
        @logger.info("Draining: #{@args.inspect}")

        if Bosh::Agent::Config.configure
          Bosh::Agent::Monit.unmonitor_services
        end

        case @drain_type
        when "shutdown"
          drain_for_shutdown
        when "update"
          drain_for_update
        when "status"
          drain_check_status
        else
          raise Bosh::Agent::MessageHandlerError, "Unknown drain type #{@drain_type}"
        end
      end

      def drain_for_update
        if @spec.nil?
          raise Bosh::Agent::MessageHandlerError, "Drain update called without apply spec"
        end

        if @old_spec.key?('job') && drain_script_exists?
          # HACK: We go through the motions below to be able to support drain scripts written as shell scripts
          run_drain_script(job_change, hash_change, updated_packages.flatten)
        else
          0
        end
      end

      def drain_for_shutdown
        lock = Monitor.new
        delivery_cond = lock.new_cond
        delivered = false

        if @nats
          # HM notification should be in sync with VM shutdown
          Thread.new do
            @nats.publish("hm.agent.shutdown.#{@agent_id}") do
              lock.synchronize do
                delivered = true
                delivery_cond.signal
              end
            end
          end
        end

        lock.synchronize do
          delivery_cond.wait(HM_NOTIFY_TIMEOUT) unless delivered
        end

        if @old_spec.key?('job') && drain_script_exists?
          run_drain_script("job_shutdown", "hash_unchanged", [])
        else
          0
        end
      end

      def drain_check_status
        run_drain_script("job_check_status", "hash_unchanged", [])
      end

      def run_drain_script(job_updated, hash_updated, updated_packages)
        env = {
          'PATH' => '/usr/sbin:/usr/bin:/sbin:/bin',
          'BOSH_CURRENT_STATE' => Yajl::Encoder.encode(@old_spec),
          'BOSH_APPLY_SPEC' => Yajl::Encoder.encode(@spec)
        }

        # Drain contract: on success the drain script should return a number exit(0)
        options = { :unsetenv_others => options }

        args = [  env, drain_script, job_updated, hash_updated, *updated_packages ]
        args += [ :unsetenv_others => true ]
        child = POSIX::Spawn::Child.new(*args)

        result = child.out
        unless result.match(/\A-{0,1}\d+\Z/) && child.status.exitstatus == 0
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
         job_template = @old_spec['job']['template']
        "#{@base_dir}/jobs/#{job_template}/bin/drain"
      end

      def drain_script_exists?
        File.exists?(drain_script)
      end

    end
  end
end
