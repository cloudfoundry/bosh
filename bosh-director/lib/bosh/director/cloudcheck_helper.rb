# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module CloudcheckHelper
    # Helper functions that come in handy for
    # cloudcheck:
    # 1. VM/agent interactions
    # 2. VM lifecycle operations (from cloudcheck POV)
    # 3. Error handling

    # This timeout has been made pretty short mainly
    # to avoid long cloudchecks, however 10 seconds should
    # still be pretty generous interval for agent to respond.
    DEFAULT_AGENT_TIMEOUT = 10

    def cloud
      Bosh::Director::Config.cloud
    end

    def handler_error(message)
      raise Bosh::Director::ProblemHandlerError, message
    end

    def instance_name(vm)
      instance = vm.instance
      return "Unknown VM" if instance.nil?

      job = instance.job || "unknown job"
      index = instance.index || "unknown index"
      "#{job}/#{index}"
    end

    def agent_client(vm, timeout = DEFAULT_AGENT_TIMEOUT, retries = 0)
      options = {
        :timeout => timeout,
        :retry_methods => { :get_state => retries }
      }
      @clients ||= {}
      @clients[vm.agent_id] ||= AgentClient.with_defaults(vm.agent_id, options)
    end

    def agent_timeout_guard(vm, &block)
      yield agent_client(vm)
    rescue Bosh::Director::RpcTimeout
      handler_error("VM `#{vm.cid}' is not responding")
    end

    def reboot_vm(vm)
      cloud.reboot_vm(vm.cid)
      begin
        agent_client(vm).wait_until_ready
      rescue Bosh::Director::RpcTimeout
        handler_error("Agent still unresponsive after reboot")
      end
    end

    def delete_vm(vm)
      # Paranoia: don't blindly delete VMs with persistent disk
      disk_list = agent_timeout_guard(vm) { |agent| agent.list_disk }
      if disk_list.size != 0
        handler_error("VM has persistent disk attached")
      end

      cloud.delete_vm(vm.cid)
      vm.db.transaction do
        vm.instance.update(:vm => nil) if vm.instance
        vm.destroy
      end
    end

    def delete_vm_reference(vm, options={})
      if vm.cid && !options[:skip_cid_check]
        handler_error("VM has a CID")
      end

      vm.db.transaction do
        vm.instance.update(:vm => nil) if vm.instance
        vm.destroy
      end
    end

    def recreate_vm(vm)
      # Best we can do without any feedback from the agent
      # is to use the spec persisted in the DB at the time
      # of last apply call.
      # This method is somewhat similar in its nature to what
      # InstanceUpdater is doing in case of the stemcell update,
      # however we don't need to handle some advanced scenarios
      # such as disk migration.

      spec = validate_spec(vm)
      env = validate_env(vm)

      resource_pool_spec = spec.fetch("resource_pool", {})
      stemcell = find_stemcell(resource_pool_spec.fetch("stemcell", {}))

      deployment = vm.deployment
      handler_error("VM doesn't belong to any deployment") unless deployment

      instance = vm.instance
      disk_cid = instance ? instance.persistent_disk_cid : nil

      # One situation where this handler is actually useful is when
      # VM has already been deleted but something failed after that
      # and it is still referenced in DB. In that case it makes sense
      # to ignore "VM not found" errors in `delete_vm' and let the method
      # proceed creating a new VM. Other errors are not forgiven.
      begin
        cloud.delete_vm(vm.cid)
      rescue Bosh::Clouds::VMNotFound => e
        @logger.warn("VM '#{vm.cid}' might have already been deleted from the cloud")
      end

      vm.db.transaction do
        instance.update(:vm => nil) if instance
        vm.destroy
      end

      cloud_properties = resource_pool_spec.fetch("cloud_properties", {})
      networks = spec["networks"]
      new_vm = VmCreator.create(deployment, stemcell, cloud_properties, networks, Array(disk_cid), env)
      new_vm.apply_spec = spec
      new_vm.save

      if instance
        instance.update(:vm => new_vm)

        # refresh metadata after new instance has been set
        VmMetadataUpdater.build.update(new_vm, {})
      end

      agent_client(new_vm).wait_until_ready

      agent_client(new_vm).update_settings(Bosh::Director::Config.trusted_certs)
      new_vm.update(:trusted_certs_sha1 => Digest::SHA1.hexdigest(Bosh::Director::Config.trusted_certs))

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
        agent_client(new_vm).mount_disk(disk_cid)
      end

      agent_client(new_vm).apply(spec)

      if instance && instance.state == "started"
        agent_client(new_vm).run_script('pre-start', {})
        agent_client(new_vm).start
      end
    end

    private

    def validate_spec(vm)
      handler_error("Unable to look up VM apply spec") unless vm.apply_spec

      spec = vm.apply_spec

      unless spec.kind_of?(Hash)
        handler_error("Invalid apply spec format")
      end

      spec
    end

    def validate_env(vm)
      handler_error("Unable to look up VM environment") unless vm.env

      env = vm.env

      unless env.kind_of?(Hash)
        handler_error("Invalid VM environment format")
      end

      env
    end

    def find_stemcell(stemcell_spec)
      stemcell_name = stemcell_spec['name']
      stemcell_version = stemcell_spec['version']

      unless stemcell_name && stemcell_version
        handler_error('Unknown stemcell name and/or version')
      end

      stemcell = Models::Stemcell.find(:name => stemcell_name, :version => stemcell_version)

      handler_error("Unable to find stemcell '#{stemcell_name} #{stemcell_version}'") unless stemcell

      stemcell
    end

    def generate_agent_id
      SecureRandom.uuid
    end

  end
end
