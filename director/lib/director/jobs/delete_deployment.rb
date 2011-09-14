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

        @event_log.begin_stage("Delete deployment", 5, [deployment.name])

        @logger.info("Acquiring deployment lock: #{deployment.name}")
        deployment_lock = Lock.new("lock:deployment:#{@deployment_name}")
        deployment_lock.lock do
          # Make sure it wasn't deleted
          deployment = Models::Deployment[:name => @deployment_name]
          raise DeploymentNotFound.new(@deployment_name) if deployment.nil?

          ThreadPool.new(:max_threads => 32).wrap do |pool|
            instances = Models::Instance.filter(:deployment_id => deployment.id)
            count = instances.count
            @event_log.track_and_log("Deleting #{count} instances") do |ticker|
              instances.each do |instance|
                pool.process do
                  delete_instance(instance)
                  ticker.advance(100.0 / count, "instance #{instance.job}/#{instance.index}")
                end
              end
            end
            pool.wait

            vms = Models::Vm.filter(:deployment_id => deployment.id)

            @event_log.track_and_log("Deleting idle VMs") do |ticker|
              vms.each do |vm|
                pool.process do
                  delete_vm(vm)
                  ticker.advance(100.0 / vms.size, "VM: + #{vm.cid}")
                end
              end
            end
          end

          @event_log.track_and_log("Remove all stemcells") do
            deployment.remove_all_stemcells
          end

          @event_log.track_and_log("Remove all release versions") do
            deployment.remove_all_release_versions
          end

          @event_log.track_and_log("Destroy deployment: #{@deployment_name}") do
            deployment.destroy
          end
          "/deployments/#{@deployment_name}"
        end
      end
    end
  end
end
