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
              # TODO: by default we should not ignore this, only support this when we support a forceful delete
              begin
                @logger.info("Detaching found disk: #{instance.disk_cid}")
                @cloud.detach_disk(vm.cid, instance.disk_cid)
              rescue => e
                @logger.warn("Could not detach disk from VM: #{e} - #{e.backtrace.join("")}")
              end
            end

            # TODO: by default we should not ignore this, only support this when we support a forceful delete
            begin
              @logger.info("Deleting found disk: #{instance.disk_cid}")
              @cloud.delete_disk(instance.disk_cid)
            rescue => e
              @logger.warn("Could not delete disk: #{e} - #{e.backtrace.join("")}")
            end
          end

          instance.destroy

          if vm
            delete_vm(vm)
          end
        end
      end

      def delete_vm(vm)
        with_thread_name("delete_vm(#{vm.cid})") do
          @logger.info("Deleting VM: #{vm.cid}")
          # TODO: by default we should not ignore this, only support this when we support a forceful delete
          begin
            @cloud.delete_vm(vm.cid)
          rescue => e
            @logger.warn("Could not delete VM: #{e} - #{e.backtrace.join("")}")
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

          deployment.stemcells.each { |stemcell| stemcell.remove_deployment(deployment) }
          deployment.destroy
          "/deployments/#{@deployment_name}"
        end
      end
    end
  end
end
