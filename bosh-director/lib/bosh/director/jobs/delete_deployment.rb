module Bosh::Director
  module Jobs
    class DeleteDeployment < BaseJob
      include DnsHelper
      include LockHelper

      @queue = :normal

      def self.job_type
        :delete_deployment
      end

      def initialize(deployment_name, options = {})
        @deployment_name = deployment_name
        @force = options['force']
        @keep_snapshots = options['keep_snapshots']
        @cloud = Config.cloud
        @deployment_manager = Api::DeploymentManager.new
      end

      def perform
        logger.info("Deleting: #{@deployment_name}")

        with_deployment_lock(@deployment_name) do
          deployment_model = @deployment_manager.find_by_name(@deployment_name)

          deleter_options = {
            force: @force,
            keep_snapshots_in_the_cloud: @keep_snapshots
          }

          # using_global_networking is always true
          ip_provider = DeploymentPlan::IpProviderV2.new(DeploymentPlan::InMemoryIpRepo.new(logger), DeploymentPlan::VipRepo.new(logger), true, logger)
          skip_drain_decider = DeploymentPlan::AlwaysSkipDrain.new

          if Config.dns_enabled?
            # Load these constants here while on the Job's 'main' thread.
            # These constants are not 'require'd, they are 'autoload'ed
            # in models.rb. The code in InstanceDeleter will run in a ThreadPool,
            # one thread per instance. These threads conditionally reference these constants.
            # We're seeing that in 1.9.3 that sometimes
            # the constants loaded from one thread are not visible to other threads,
            # causing failures.
            # These constants cannot be required because they are Sequel model classes
            # that refer to database configuration that is only present when the (optional)
            # powerdns job is present and configured and points to a valid DB.
            # This is an attempt to make sure the constants are loaded
            # before forking off to other threads, hopefully eliminating the errors.
            Bosh::Director::Models::Dns::Record.class
            Bosh::Director::Models::Dns::Domain.class
          end

          instance_deleter = InstanceDeleter.new(ip_provider, skip_drain_decider, deleter_options)

          dns_manager = DnsManager.new(logger)
          deployment_deleter = DeploymentDeleter.new(event_log, logger, dns_manager, Config.max_threads, Config.dns_enabled?)

          vm_deleter = Bosh::Director::VmDeleter.new(@cloud, logger, force: @force)
          deployment_deleter.delete(deployment_model, instance_deleter, vm_deleter)

          "/deployments/#{@deployment_name}"
        end
      end
    end
  end
end
