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
        @blobstore = App.instance.blobstores.blobstore

        @vm_deleter = Bosh::Director::VmDeleter.new(@cloud, logger, force: @force)
      end

      def perform
        logger.info("Deleting: #{@deployment_name}")

        with_deployment_lock(@deployment_name) do
          deployment_model = find_deployment(@deployment_name)

          planner_factory = DeploymentPlan::PlannerFactory.create(Config.event_log, Config.logger)
          deployment_plan = planner_factory.create_from_model(deployment_model)

          deleter = InstanceDeleter.new(deployment_plan, force: @force, keep_snapshots: @keep_snapshots)
          instances = deployment_plan.existing_instances.map do |instance_model|
            DeploymentPlan::ExistingInstance.create_from_model(instance_model, logger)
          end

          event_log_stage = event_log.begin_stage('Deleting instances',instances.size)

          deleter.delete_instances(instances, event_log_stage, max_threads: Config.max_threads)

          # For backwards compatibility for VMs that did not have instances
          delete_vms(deployment_model.vms)

          event_log.begin_stage('Removing deployment artifacts', 3)

          track_and_log('Detach stemcells') do
            deployment_model.remove_all_stemcells
          end

          track_and_log('Detaching releases') do
            deployment_model.remove_all_release_versions
          end

          event_log.begin_stage('Deleting properties', deployment_model.properties.count)
          logger.info('Deleting deployment properties')
          deployment_model.properties.each do |property|
            event_log.track(property.name) do
              property.destroy
            end
          end

          track_and_log('Delete DNS records') do
            delete_dns
          end

          track_and_log('Destroy deployment') do
            deployment_model.destroy
          end

          "/deployments/#{@deployment_name}"
        end
      end

      private

      def find_deployment(name)
        @deployment_manager.find_by_name(name)
      end

      def delete_vms(vms)
        ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
          event_log.begin_stage('Deleting idle VMs', vms.count)

          vms.each do |vm|
            pool.process do
              event_log.track("#{vm.cid}") do
                logger.info("Deleting idle vm #{vm.cid}")
                @vm_deleter.delete_vm(vm)
              end
            end
          end
        end
      end

      def delete_dns
        if Config.dns_enabled?
          record_pattern = ['%', canonical(@deployment_name), dns_domain_name].join('.')
          delete_dns_records(record_pattern)
        end
      end

      def ignoring_errors_when_forced
        yield
      rescue => e
        raise unless @force
        logger.warn(e.backtrace.join("\n"))
        logger.info('Force deleting is set, ignoring exception')
      end
    end
  end
end
