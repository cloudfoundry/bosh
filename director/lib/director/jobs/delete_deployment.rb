# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Jobs
    class DeleteDeployment < BaseJob

      @queue = :normal

      def initialize(deployment_name, options = {})
        super

        @deployment_name = deployment_name
        @force = options["force"]
        @cloud = Config.cloud
        @deployment_manager = Api::DeploymentManager.new
      end

      def perform
        logger.info("Deleting: #{@deployment_name}")

        deployment = find_deployment(@deployment_name)

        logger.info("Acquiring deployment lock: #{deployment.name}")
        deployment_lock = Lock.new("lock:deployment:#{@deployment_name}")

        deployment_lock.lock do
          # Make sure it wasn't deleted
          deployment = find_deployment(@deployment_name)

          ThreadPool.new(:max_threads => 32).wrap do |pool|
            delete_instances(deployment, pool)
            pool.wait
            delete_vms(deployment, pool)
          end

          event_log.begin_stage("Removing deployment artifacts", 3)
          track_and_log("Detach stemcells") do
            deployment.remove_all_stemcells
          end

          track_and_log("Detaching releases") do
            deployment.remove_all_release_versions
          end

          event_log.begin_stage("Deleting properties",
                                 deployment.properties.count)
          logger.info("Deleting deployment properties")
          deployment.properties.each do |property|
            event_log.track(property.name) do
              property.destroy
            end
          end

          track_and_log("Destroy deployment") do
            deployment.destroy
          end
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
              agent = AgentClient.new(vm.agent_id)
              agent.stop
            end
          end

          instance.persistent_disks.each do |disk|
            if disk.active && vm && vm.cid && disk.disk_cid
              if vm.agent_id
                ignoring_errors_when_forced do
                  agent = AgentClient.new(vm.agent_id)
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
                @cloud.delete_disk(disk.disk_cid)
              end
            end

            disk.destroy
          end

          instance.destroy

          delete_vm(vm) if vm
        end
      end

      def delete_vm(vm)
        if vm.cid
          ignoring_errors_when_forced do
            @cloud.delete_vm(vm.cid)
          end
        end

        vm.destroy
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
