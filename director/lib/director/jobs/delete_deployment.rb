module Bosh::Director
  module Jobs
    class DeleteDeployment
      extend BaseJob

      @queue = :normal

      def initialize(deployment_name)
        @logger = Config.logger
        @logger.info("Deleting: #{deployment_name}")
        @deployment_name = deployment_name
        @cloud = Config.cloud
      end

      def delete_instance(instance)
        with_thread_name("delete_instance(#{instance.job}/#{instance.index})") do
          @logger.info("Deleting instance: #{instance.job}/#{instance.index}")
          vm = instance.vm

          if instance.disk_cid
            if vm
              @logger.info("Detaching found disk: #{instance.disk_cid}")
              @cloud.detach_disk(vm.cid, instance.disk_cid)
            end
            @logger.info("Deleting found disk: #{instance.disk_cid}")
            @cloud.delete_disk(instance.disk_cid)
          end

          if vm
            delete_vm(vm)
          end

          instance.delete
        end
      end

      def delete_vm(vm)
        with_thread_name("delete_vm(#{vm.cid})") do
          @logger.info("Deleting VM: #{vm.cid}")
          @cloud.delete_vm(vm.cid)
          vm.delete
        end
      end

      def perform
        deployment = Models::Deployment.find(:name => @deployment_name).first
        raise DeploymentNotFound.new(@deployment_name) if deployment.nil?

        @logger.info("Acquiring deployment lock: #{deployment.name}")
        deployment_lock = Lock.new("lock:deployment:#{@deployment_name}")
        deployment_lock.lock do
          # Make sure it wasn't deleted
          deployment = Models::Deployment.find(:name => @deployment_name).first
          raise DeploymentNotFound.new(@deployment_name) if deployment.nil?

          pool = ThreadPool.new(:min_threads => 1, :max_threads => 32)
          instances = Models::Instance.find(:deployment_id => deployment.id)
          @logger.info("Deleting instances")
          instances.each do |instance|
            pool.process do
              delete_instance(instance)
            end
          end
          pool.wait

          vms = Models::Vm.find(:deployment_id => deployment.id)
          @logger.info("Deleting idle VMs")
          vms.each do |vm|
            pool.process do
              delete_vm(vm)
            end
          end
          pool.wait

          deployment.delete
        end
      end
    end
  end
end
