module Bosh::Director
  module ProblemHandlers
    class UnresponsiveAgent < Base

      register_as :unresponsive_agent
      auto_resolution :ignore

      def initialize(vm_id, data)
        super
        @vm = Models::Vm[vm_id]

        if @vm.nil?
          handler_error("VM `#{vm_id}' is no longer in the database")
        end

        if @vm.agent_id.nil?
          handler_error("VM `#{vm_id}' doesn't have an agent id")
        end

        if @vm.cid.nil?
          handler_error("VM `#{vm_id}' doesn't have a cloud id")
        end
      end

      def description
        instance = @vm.instance
        if instance.nil?
          vm_description = "Unknown VM"
        else
          job = instance.job || "unknown job"
          index = instance.index || "unknown index"
          vm_description = "#{job}/#{index}"
        end
        "#{vm_description} (#{@vm.cid}) is not responding"
      end

      resolution :ignore do
        plan { "Ignore problem" }
        action { }
      end

      resolution :reboot_vm do
        plan { "Reboot VM" }
        action { validate; reboot_vm }
      end

      resolution :recreate_vm do
        plan { "Recreate VM using last known apply spec" }
        action { validate; recreate_vm }
      end

      def agent_alive?
        agent_client(@vm).ping
        true
      rescue Bosh::Director::Client::TimeoutException
        false
      end

      def validate
        # TODO: think about flapping agent problem
        if agent_alive?
          handler_error("Agent is responding now, skipping reboot")
        end
      end

      def reboot_vm
        cloud.reboot_vm(@vm.cid)
        begin
          agent_client(@vm).wait_until_ready
        rescue Bosh::Director::Client::TimeoutException
          handler_error("Agent still unresponsive after reboot")
        end
      end

      def delete_vm
        # TODO: this is useful to kill stuck compilation VMs
      end

      def recreate_vm
        # Best we can do without any feedback from the agent
        # is to use the spec persisted in the DB at the time
        # of last apply call.
        # This method is somewhat similar in its nature to what
        # InstanceUpdater is doing in case of the stemcell update,
        # however we don't need to handle some advanced scenarios
        # such as disk migration.

        if @vm.apply_spec.nil?
          handler_error("Unable to look up VM apply spec")
        end

        spec = @vm.apply_spec

        unless spec.kind_of?(Hash)
          handler_error("Invalid apply spec format")
        end

        instance = @vm.instance
        deployment = @vm.deployment

        if deployment.nil?
          handler_error("VM doesn't belong to any deployment")
        end

        disk_cid = instance ? instance.persistent_disk_cid : nil

        resource_pool_spec = spec["resource_pool"] || {}
        network_spec = spec["networks"]

        cloud_properties = resource_pool_spec["cloud_properties"] || {}
        stemcell_spec = resource_pool_spec["stemcell"] || {}
        env = resource_pool_spec["env"]

        stemcell_name = stemcell_spec["name"]
        stemcell_version = stemcell_spec["version"]

        if stemcell_name.nil? || stemcell_version.nil?
          handler_error("Unknown stemcell name and/or version")
        end

        stemcell = Models::Stemcell.find(:name => stemcell_name, :version => stemcell_version)

        if stemcell.nil?
          handler_error("Unable to find stemcell `#{stemcell_name} #{stemcell_version}'")
        end

        # One situation where this handler is actually useful is when
        # VM has already been deleted but something failed after that
        # and it is still referenced in DB. In that case it makes sense
        # to ignore "VM not found" errors in `delete_vm' and let the method
        # proceed creating a new VM. Other errors are not forgiven.
        begin
          if disk_cid
            cloud.detach_disk(@vm.cid, disk_cid)
          end

          cloud.delete_vm(@vm.cid)
        rescue VMNotFound => e
          @logger.warn("VM `#{@vm.cid}' might have already been deleted from the cloud")
        end

        new_agent_id = generate_agent_id

        new_vm = Models::Vm.new
        new_vm.deployment = deployment
        new_vm.agent_id = new_agent_id
        new_vm.cid = cloud.
          create_vm(new_agent_id, stemcell.cid,
                    cloud_properties, network_spec,
                    Array(disk_cid), env)
        new_vm.apply_spec = spec
        new_vm.save

        new_vm.db.transaction do
          instance.update(:vm => new_vm) if instance
          @vm.destroy
        end

        agent_client(new_vm).wait_until_ready

        # After this point agent is actually responding to
        # pings, so if the rest of this handler fails
        # bcck won't find this type of problem again
        # but regular deployment will fail with "out-of-sync"
        # error (as we now have an instance that points to
        # VM that reports empty state). This problem
        # should be handled by "out-of-sync VM" problem handler.

        if disk_cid
          # N.B. attach_disk might fail if disk image is no longer
          # there or for some other reason. Generally it means
          # the data has been lost (e.g. someone deleted VM from vCenter
          # along with the disk.
          cloud.attach_disk(new_vm.cid, disk_cid)
          agent_client(new_vm).run_task(:mount_disk, disk_cid)
        end

        agent_client(new_vm).run_task(:apply, spec)

        if instance && instance.state == "started"
          agent_client(new_vm).start
        end
      end

      private

      def generate_agent_id
        UUIDTools::UUID.random_create.to_s
      end

    end
  end
end
