module Bosh::Agent::Message
  class Prepare < Base
    def initialize(args)
      @platform = Bosh::Agent::Config.platform

      if args.size < 1
        raise ArgumentError, "not enough arguments"
      end

      @new_spec = args.first
      unless @new_spec.is_a?(Hash)
        raise ArgumentError, "invalid spec, Hash expected, " +
          "#{@new_spec.class} given"
      end
    end

    def prepare
      initialize_plans

      %w(bosh jobs packages monit).each do |dir|
        FileUtils.mkdir_p(File.join(base_dir, dir))
      end

      logger.info("Preparing: #{@new_spec.inspect}")

      if @new_plan.configured?
        begin
          apply_job
          apply_packages
          log_bit_download_with_agent_state
        rescue Exception => e
          raise Bosh::Agent::MessageHandlerError,
                "#{e.message}: #{e.backtrace}"
        end
      end
    end

    private

    def initialize_plans
      initialize_networks

      @old_spec = Bosh::Agent::Config.state.to_hash

      @old_plan = Bosh::Agent::ApplyPlan::Plan.new(@old_spec)
      @new_plan = Bosh::Agent::ApplyPlan::Plan.new(@new_spec)
    end

    def initialize_networks
      if @new_spec["networks"]
        @new_spec["networks"].each do |network, properties|
          infrastructure = Bosh::Agent::Config.infrastructure
          network_settings =
            infrastructure.get_network_settings(network, properties)
          logger.debug("current network settings from VM: #{network_settings.inspect}")
          logger.debug("new network settings to be applied: #{properties.inspect}")
          if network_settings
            @new_spec["networks"][network].merge!(network_settings)
            logger.debug("merged network settings: #{@new_spec["networks"].inspect}")
          end
        end
      end
    end

    def apply_job
      if @new_plan.has_jobs?
        @new_plan.install_jobs
      else
        logger.info("No job")
      end
    end

    def apply_packages
      if @new_plan.has_packages?
        @new_plan.install_packages
      else
        logger.info("No packages")
      end
    end

    def log_bit_download_with_agent_state
      @old_spec['prepared_spec'] = @new_spec
      Bosh::Agent::Config.state.write(@old_spec)
    end
  end
end
