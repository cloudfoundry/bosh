# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Jobs
    class DeleteDeployment < BaseJob

      @queue = :normal

      def initialize(deployment_name, options = {})
        super
        @deployment_name = deployment_name
        @force = options["force"] || false
        @cloud = Config.cloud
      end

      def detach_delete_disk(disk, vm, force)
        # detach the disk from the vm
        if vm
          begin
            @logger.info("Detaching disk: #{disk.disk_cid} from vm (#{vm.cid})")
            @cloud.detach_disk(vm.cid, disk.disk_cid)
          rescue => e
            @logger.warn("Could not detach disk from VM: #{e} - #{e.backtrace.join("")}")
            raise unless force
          end
        end

        #delete the disk
        begin
          @logger.info("Deleting found disk: #{disk.disk_cid}")
          @cloud.delete_disk(disk.disk_cid)
        rescue => e
          @logger.warn("Could not delete disk: #{e} - #{e.backtrace.join("")}")
          raise unless force
        end
        disk.destroy
      end

      def delete_instance(instance)
        with_thread_name("delete_instance(#{instance.job}/#{instance.index})") do
          @logger.info("Deleting instance: #{instance.job}/#{instance.index}")

          vm = instance.vm
          disks = instance.persistent_disks
          disks.each { |disk| detach_delete_disk(disk, vm, @force) }
          instance.destroy
          if vm
            delete_vm(vm)
          end
        end
      end

      def delete_vm(vm)
        with_thread_name("delete_vm(#{vm.cid})") do
          @logger.info("Deleting VM: #{vm.cid}")
          begin
            @cloud.delete_vm(vm.cid)
          rescue => e
            @logger.warn("Could not delete VM: #{e} - #{e.backtrace.join("")}")
            raise unless @force
          end
          vm.destroy
        end
      end

      def perform
        @logger.info("Deleting: #{@deployment_name}")

        deployment = Models::Deployment[:name => @deployment_name]
        raise DeploymentNotFound.new(@deployment_name) if deployment.nil?

        @logger.info("Acquiring deployment lock: #{deployment.name}")
        deployment_lock = Lock.new("lock:deployment:#{@deployment_name}")
        deployment_lock.lock do
          # Make sure it wasn't deleted
          deployment = Models::Deployment[:name => @deployment_name]
          raise DeploymentNotFound.new(@deployment_name) if deployment.nil?

          instances = Models::Instance.filter(:deployment_id => deployment.id)

          @event_log.begin_stage("Deleting instances", instances.count)
          ThreadPool.new(:max_threads => 32).wrap do |pool|
            instances.each do |instance|
              pool.process do
                @event_log.track("#{instance.job}/#{instance.index}") do
                  @logger.info("Deleting #{instance.job}/#{instance.index}")
                  delete_instance(instance)
                end
              end
            end
            pool.wait

            vms = Models::Vm.filter(:deployment_id => deployment.id)

            @event_log.begin_stage("Deleting idle VMs", vms.count)
            vms.each do |vm|
              pool.process do
                @event_log.track("#{vm.cid}") do
                  @logger.info("Deleting idle vm #{vm.cid}")
                  delete_vm(vm)
                end
              end
            end
          end

          @event_log.begin_stage("Removing deployment artifacts", 3)
          track_and_log("Detach stemcells") do
            deployment.remove_all_stemcells
          end

          track_and_log("Detaching release versions") do
            deployment.remove_all_release_versions
          end

          @event_log.begin_stage("Deleting properties", deployment.properties.count)
          @logger.info("Deleting deployment properties")
          deployment.properties.each do |property|
            @event_log.track(property.name) do
              property.destroy
            end
          end

          track_and_log("Destroy deployment") do
            deployment.destroy
          end
          "/deployments/#{@deployment_name}"
        end
      end
    end
  end
end
