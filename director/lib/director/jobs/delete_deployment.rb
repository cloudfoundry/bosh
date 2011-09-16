module Bosh::Director
  module Jobs
    class DeleteDeployment < BaseJob

      @queue = :normal

      def initialize(deployment_name, options = {})
        @logger = Config.logger
        @logger.info("Deleting: #{deployment_name}")
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
          disk.destroy
        rescue => e
          @logger.warn("Could not delete disk: #{e} - #{e.backtrace.join("")}")
          raise unless force
        end
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
        deployment = Models::Deployment[:name => @deployment_name]
        raise DeploymentNotFound.new(@deployment_name) if deployment.nil?

        @logger.info("Acquiring deployment lock: #{deployment.name}")
        deployment_lock = Lock.new("lock:deployment:#{@deployment_name}")
        deployment_lock.lock do
          # Make sure it wasn't deleted
          deployment = Models::Deployment[:name => @deployment_name]
          raise DeploymentNotFound.new(@deployment_name) if deployment.nil?

          ThreadPool.new(:max_threads => 32).wrap do |pool|
            instances = Models::Instance.filter(:deployment_id => deployment.id)
            @logger.info("Deleting instances")
            instances.each do |instance|
              pool.process do
                delete_instance(instance)
              end
            end
            pool.wait

            vms = Models::Vm.filter(:deployment_id => deployment.id)
            @logger.info("Deleting idle VMs")
            vms.each do |vm|
              pool.process do
                delete_vm(vm)
              end
            end
          end

          deployment.remove_all_stemcells
          deployment.remove_all_release_versions
          deployment.destroy
          "/deployments/#{@deployment_name}"
        end
      end
    end
  end
end
