module Bosh::Director
  module Jobs
    class DeleteDeployment < BaseJob
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

          # using_global_networking is always true
          ip_provider = DeploymentPlan::IpProviderV2.new(DeploymentPlan::InMemoryIpRepo.new(logger), DeploymentPlan::VipRepo.new(logger), true, logger)

          dns_manager = DnsManager.create
          disk_manager = InstanceUpdater::DiskManager.new(@cloud, logger, keep_snapshots_in_the_cloud: @keep_snapshots)
          instance_deleter = InstanceDeleter.new(ip_provider, dns_manager, disk_manager, force: @force)
          deployment_deleter = DeploymentDeleter.new(event_log, logger, dns_manager, Config.max_threads)

          vm_deleter = Bosh::Director::VmDeleter.new(@cloud, logger, force: @force)
          deployment_deleter.delete(deployment_model, instance_deleter, vm_deleter)

          "/deployments/#{@deployment_name}"
        end
      end

      def find_deployment(name)
        @deployment_manager.find_by_name(name)
      end

      def delete_instances(deployment, pool)
        instances = deployment.job_instances
        event_log.begin_stage("Deleting instances", instances.count)

        instances.each do |instance|
          pool.process do
            desc = "#{instance.job}/#{instance.index}"
            event_log.track(desc) do
              logger.info("Deleting #{desc}")
              delete_instance(instance)
            end
          end
        end
      end

      def delete_vms(deployment, pool)
        vms = deployment.vms
        event_log.begin_stage("Deleting idle VMs", vms.count)

        vms.each do |vm|
          pool.process do
            event_log.track("#{vm.cid}") do
              logger.info("Deleting idle vm #{vm.cid}")
              delete_vm(vm)
            end
          end
        end
      end

      def delete_instance(instance)
        desc = "#{instance.job}/#{instance.index}"
        with_thread_name("delete_instance(#{desc})") do
          logger.info("Deleting instance: #{desc}")

          vm = instance.vm

          if vm && vm.agent_id
            ignoring_errors_when_forced do
              agent = AgentClient.with_defaults(vm.agent_id)
              agent.stop
            end
          end

          instance.persistent_disks.each do |disk|
            if disk.active && vm && vm.cid && disk.disk_cid
              if vm.agent_id
                ignoring_errors_when_forced do
                  agent = AgentClient.with_defaults(vm.agent_id)
                  agent.unmount_disk(disk.disk_cid)
                end
              end

              ignoring_errors_when_forced do
                # If persistent disk has been mounted but
                # clean_shutdown above did not unmount it
                # properly (i.e. for wedged deployment),
                # detach_disk might hang indefinitely.
                # Right now it's up to cloudcheck handle
                # that but 'force' might be added to CPI
                # in the future.
                @cloud.detach_disk(vm.cid, disk.disk_cid)
              end
            end

            if disk.disk_cid
              ignoring_errors_when_forced do
                delete_snapshots(disk)
                @cloud.delete_disk(disk.disk_cid)
              end
            end

            disk.destroy
          end

          ignoring_errors_when_forced do
            RenderedJobTemplatesCleaner.new(instance, @blobstore, @logger).clean_all
          end

          instance.destroy

          delete_vm(vm) if vm
        end
      end

      def delete_snapshots(disk)
        @keep_snapshots ? disk.snapshots.each(&:delete) : Api::SnapshotManager.delete_snapshots(disk.snapshots)
      end

      def delete_vm(vm)
        if vm.cid
          ignoring_errors_when_forced do
            @cloud.delete_vm(vm.cid)
          end
        end
        vm.destroy
      end

      def delete_dns(name)
        if Config.dns_enabled?
          record_pattern = ["%", canonical(name), dns_domain_name].join(".")
          delete_dns_records(record_pattern)
        end
      end

      def ignoring_errors_when_forced
        yield
      rescue => e
        raise unless @force
        logger.warn(e.backtrace.join("\n"))
        logger.info("Force deleting is set, ignoring exception")
      end
    end
  end
end
