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

      def delete_instance(instance)
        with_thread_name("delete_instance(#{instance.job}/#{instance.index})") do
          @logger.info("Deleting instance: #{instance.job}/#{instance.index}")

          vm = instance.vm

          if instance.disk_cid
            if vm
              begin
                @logger.info("Detaching found disk: #{instance.disk_cid}")
                @cloud.detach_disk(vm.cid, instance.disk_cid)
              rescue => e
                @logger.warn("Could not detach disk from VM: #{e} - #{e.backtrace.join("")}")
                raise unless @force
              end
            end

            begin
              @logger.info("Deleting found disk: #{instance.disk_cid}")
              @cloud.delete_disk(instance.disk_cid)
            rescue => e
              @logger.warn("Could not delete disk: #{e} - #{e.backtrace.join("")}")
              raise unless @force
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

          @event_log.begin_stage("Deleting instances", instances.count, [deployment.name])
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

            @event_log.begin_stage("Deleting idle VMs", vms.count, [deployment.name])
            vms.each do |vm|
              pool.process do
                @event_log.track("#{vm.cid}") do
                  @logger.info("Deleting idle vm #{vm.cid}")
                  delete_vm(vm)
                end
              end
            end
          end

          @event_log.begin_stage("Removing deployment artifacts", 3, [deployment.name])
          track_and_log("Detach stemcells") do
            deployment.remove_all_stemcells
          end

          track_and_log("Detach release version") do
            deployment.remove_all_release_versions
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
