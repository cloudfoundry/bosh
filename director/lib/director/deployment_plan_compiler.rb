module Bosh::Director
  class DeploymentPlanCompiler
    include DnsHelper
    include IpUtil

    def initialize(deployment_plan)
      @deployment_plan = deployment_plan
      @cloud = Config.cloud
      @logger = Config.logger
      @event_log = Config.event_log
    end

    def process_ip_reservations(state)
      # TODO CLEANUP: this should be refactored to clarify reservation logic and avoid passing this hash around
      # (i.e. replaced with some abstraction for ip reservations)
      ip_reservations = {}
      state["networks"].each do |name, network_config|
        network = @deployment_plan.network(name)
        if network
          ip = ip_to_i(network_config["ip"])
          reservation = network.reserve_ip(ip)
          if reservation
            ip_reservations[name] = {:ip => ip, :static? => reservation == :static}
          end
        end
      end
      ip_reservations
    end

    def verify_state(vm, instance, state)
      # TODO: consider a special kind of exception instead of generic RuntimeError
      if instance && instance.deployment_id != vm.deployment_id
        raise "VM `#{vm.cid}' is out of sync: DB record mismatch, " +
          "instance belongs to deployment `#{instance.deployment_id}', " +
          "VM belongs to deployment `#{vm.deployment_id}'"
      end

      unless state.kind_of?(Hash)
        @logger.error("Invalid state for `#{vm.cid}': #{state.pretty_inspect}")
        raise "VM `#{vm.cid}' returns invalid state: expected Hash, got #{state.class}"
      end

      actual_deployment_name = state["deployment"]
      expected_deployment_name = @deployment_plan.deployment.name

      if actual_deployment_name != expected_deployment_name
        raise "VM `#{vm.cid}' is out of sync: expected to be a part of " +
          "`#{expected_deployment_name}' deployment " +
          "but is actually a part of `#{actual_deployment_name}' deployment"
      end

      actual_job = state["job"].is_a?(Hash) ? state["job"]["name"] : nil
      actual_index = state["index"]

      if instance.nil? && !actual_job.nil?
        raise "VM `#{vm.cid}' is out of sync: it reports itself as " +
          "`#{actual_job}/#{actual_index}' but there is no instance referencing it"
      end

      if instance && (instance.job != actual_job || instance.index != actual_index)
        raise "VM `#{vm.cid}' is out of sync: it reports itself as " +
          "`#{actual_job}/#{actual_index}' but according to DB " +
          "it is `#{instance.job}/#{instance.index}'"
      end
    end

    def bind_deployment
      Models::Deployment.db.transaction do
        deployment = Models::Deployment.find(:name => @deployment_plan.name)
        # HACK, since canonical uniqueness is not enforced in the DB
        if deployment.nil?
          canonical_name_index = Set.new
          Models::Deployment.each { |other_deployment| canonical_name_index << canonical(other_deployment.name) }
          if canonical_name_index.include?(@deployment_plan.canonical_name)
            raise "Invalid deployment name: '#{@deployment_plan.name}', canonical name already taken."
          end
          deployment = Models::Deployment.create(:name => @deployment_plan.name)
        end
        @deployment_plan.deployment = deployment
      end
    end

    def bind_release
      release_spec = @deployment_plan.release
      release = Models::Release[:name => release_spec.name]
      raise "Can't find release" if release.nil?
      @logger.debug("Found release: #{release.pretty_inspect}")
      release_spec.release = release
      release_version = Models::ReleaseVersion[:release_id => release.id,
                                               :version    => release_spec.version]
      raise "Can't find release version" if release_version.nil?
      @logger.debug("Found release version: #{release_version.pretty_inspect}")
      release_spec.release_version = release_version

      @logger.debug("Locking the release from deletion")
      deployment = @deployment_plan.deployment
      deployment.release = release
      deployment.save

      unless deployment.release_versions.include?(release_version)
        @logger.debug("Binding release version to deployment")
        deployment.add_release_version(release_version)
      end
    end

    def bind_existing_deployment
      lock = Mutex.new
      idle_vms_without_reservations = []

      ThreadPool.new(:max_threads => 32).wrap do |pool|
        vms = Models::Vm.filter(:deployment_id => @deployment_plan.deployment.id)
        vms.each do |vm|
          pool.process do
            with_thread_name("bind_existing_deployment(#{vm.agent_id})") do
              @logger.debug("Requesting current VM state for: #{vm.agent_id}")
              instance = vm.instance
              agent = AgentClient.new(vm.agent_id)
              state = agent.get_state

              # Persisting apply spec for VMs that were introduced before we started
              # persisting it on apply itself (this is for cloudcheck purposes only)
              if vm.apply_spec.nil?
                # The assumption is that apply_spec <=> VM state
                vm.update(:apply_spec => state)
              end

              @logger.debug("Received VM state: #{state.pretty_inspect}")

              verify_state(vm, instance, state)
              @logger.debug("Verified VM state")

              lock.synchronize do
                @logger.debug("Processing IP reservations")
                ip_reservations = process_ip_reservations(state)
                @logger.debug("Processed IP reservations")

                # Does the job instance exist in the new deployment?
                if instance
                  disk_size = state["persistent_disk"].to_i
                  persistent_disk = instance.persistent_disk

                  # This is to support legacy deployments where we did not have
                  # the disk_size specified.
                  if disk_size != 0 && persistent_disk && persistent_disk.size == 0
                    persistent_disk.update(:size => disk_size)
                  end

                  @logger.debug("Binding instance VM")
                  if (job = @deployment_plan.job(instance.job)) && (instance_spec = job.instance(instance.index))
                    @logger.debug("Found job and instance spec")
                    instance_spec.instance = instance
                    instance_spec.current_state = state

                    @logger.debug("Copying network reservations")
                    # Copy network reservations
                    instance_spec.networks.each do |network_config|
                      reservation = ip_reservations[network_config.name]
                      network_config.use_reservation(reservation[:ip], reservation[:static?]) if reservation
                    end

                    @logger.debug("Copying resource pool reservation")
                    # Copy resource pool reservation
                    instance_spec.job.resource_pool.mark_active_vm
                  else
                    @logger.debug("Job/instance not found, marking for deletion")
                    @deployment_plan.delete_instance(instance)
                  end
                else
                  @logger.debug("Binding resource pool VM")
                  resource_pool = @deployment_plan.resource_pool(state["resource_pool"]["name"])

                  if resource_pool
                    @logger.debug("Adding to resource pool")

                    idle_vm = resource_pool.add_idle_vm
                    idle_vm.vm = vm
                    idle_vm.current_state = state

                    network_reservation = ip_reservations[resource_pool.network.name]
                    if network_reservation
                      if network_reservation[:static?]
                        @logger.debug("Resource pool VM `#{vm.cid}' has static reservation, releasing IP")
                        resource_pool.network.release_ip(network_reservation[:ip])
                        # We can't allocate dynamic IPs here, as we probably didn't process
                        # the rest reservations yet and some of them might hold onto these IPs.
                        # Just noticing this VM instead:
                        idle_vms_without_reservations << idle_vm
                      else
                        idle_vm.ip = network_reservation[:ip]
                      end
                    else
                      @logger.debug("No network reservation for VM `#{vm.cid}'")
                    end
                  else
                    @logger.debug("Resource pool doesn't exist, marking for deletion")
                    @deployment_plan.delete_vm(vm)
                  end
                end
                @logger.debug("Finished binding VM")
              end # synchronize
            end
          end
        end
      end # Thread pool

      idle_vms_without_reservations.each do |idle_vm|
        # This will trigger recreating these idle VMs during resource pool update
        # (see ResourcePoolUpdater#delete_outdated_idle_vms)
        @logger.debug("Allocating dynamic IP for `#{idle_vm.vm.cid}'")
        idle_vm.ip = idle_vm.resource_pool.network.allocate_dynamic_ip
      end
    end

    def bind_resource_pools
      @deployment_plan.resource_pools.each do |resource_pool|
        missing_vms = resource_pool.size - (resource_pool.active_vms + resource_pool.idle_vms.size)

        if missing_vms > 0
          network = resource_pool.network
          missing_vms.times do
            idle_vm = resource_pool.add_idle_vm
            idle_vm.ip = network.allocate_dynamic_ip
          end
        end
      end
    end

    def bind_unallocated_vms
      @deployment_plan.jobs.each do |job|
        job.instances.each do |instance_spec|
          # create the instance model if this is a new instance
          instance = instance_spec.instance

          if instance.nil?
            # look up the instance again, in case it wasn't associated with a VM
            instance_attrs = {
              :deployment_id => @deployment_plan.deployment.id,
              :job => job.name,
              :index => instance_spec.index
            }

            instance = Models::Instance[instance_attrs] || Models::Instance.new(instance_attrs.merge(:state => "started"))
            instance_spec.instance = instance
          end

          if instance_spec.state
            # Deployment plan already has state for this instance
            instance.update(:state => instance_spec.state)
          elsif instance.state
            # Instance has its state persisted from the previous deployment
            instance_spec.state = instance.state
          else
            # Target instance state should either be persisted in DB
            # or provided via deployment plan, otherwise something is really wrong
            raise "Instance `#{instance.job}/#{instance.index}' target state cannot be determined"
          end

          unless instance.vm
            idle_vm = instance_spec.job.resource_pool.allocate_vm
            instance_spec.idle_vm = idle_vm

            if idle_vm.vm
              # try to reuse the existing reservation if possible
              instance_network = instance_spec.network(idle_vm.resource_pool.network.name)
              if instance_network && idle_vm.ip
                instance_network.use_reservation(idle_vm.ip, false)
              end
            else
              # if the VM is about to be created, then use this instance's networking configuration
              idle_vm.bound_instance = instance_spec

              # this also means we no longer need the reserved IP for this VM
              idle_vm.resource_pool.network.release_ip(idle_vm.ip)
              idle_vm.ip = nil
            end
          end
        end
      end
    end

    def bind_instance_networks
      @deployment_plan.jobs.each do |job|
        job.instances.each do |instance|
          instance.networks.each do |network_config|
            unless network_config.reserved
              network = @deployment_plan.network(network_config.name)
              # static ip that wasn't reserved
              if network_config.ip
                reservation = network.reserve_ip(network_config.ip)
                if reservation == :static
                  network_config.use_reservation(network_config.ip, true)
                elsif reservation == :dynamic
                  raise "Job: '#{job.name}'/'#{instance.index}' asked for a static IP: " +
                            "#{ip_to_netaddr(network_config.ip).ip} but it's in the dynamic pool"
                else
                  raise "Job: '#{job.name}'/'#{instance.index}' asked for a static IP: " +
                            "#{ip_to_netaddr(network_config.ip).ip} but it's already reserved/in use"
                end
              else
                ip = network.allocate_dynamic_ip
                network_config.use_reservation(ip, false)
              end
            end
          end
        end
      end
    end

    def bind_templates
      release_version = @deployment_plan.release.release_version

      template_name_index = {}
      release_version.templates.each do |template|
        template_name_index[template.name] = template
      end

      package_name_index = {}
      release_version.packages.each do |package|
        package_name_index[package.name] = package
      end

      @deployment_plan.templates.each do |template_spec|
        @logger.info("Binding template: #{template_spec.name}")
        template = template_name_index[template_spec.name]
        raise "Can't find template: #{template_spec.name}" if template.nil?
        template_spec.template = template

        packages = []
        template.package_names.each { |package_name| packages << package_name_index[package_name] }
        template_spec.packages = packages

        @logger.debug("Bound template: #{template_spec.pretty_inspect}")
      end
    end

    def bind_stemcells
      @deployment_plan.resource_pools.each do |resource_pool|
        stemcell_spec = resource_pool.stemcell
        lock = Lock.new("lock:stemcells:#{stemcell_spec.name}:#{stemcell_spec.version}", :timeout => 10)
        lock.lock do
          stemcell = Models::Stemcell[:name => stemcell_spec.name, :version => stemcell_spec.version]
          raise "Can't find stemcell: #{stemcell_spec.name}/#{stemcell_spec.version}" unless stemcell
          if stemcell.deployments_dataset.filter(:deployment_id => @deployment_plan.deployment.id).empty?
            stemcell.add_deployment(@deployment_plan.deployment)
          end
          stemcell_spec.stemcell = stemcell
        end
      end
    end

    def bind_configuration
      @deployment_plan.jobs.each { |job| ConfigurationHasher.new(job).hash }
    end

    def bind_dns
      domain = Models::Dns::Domain.find_or_create(:name => "bosh", :type => "NATIVE")
      @deployment_plan.dns_domain = domain

      soa_record = Models::Dns::Record.find_or_create(:domain_id => domain.id, :name => "bosh", :type => "SOA")
      # TODO: make configurable?
      # The format of the SOA record is: primary_ns contact serial refresh retry expire minimum
      soa_record.content = "localhost hostmaster@localhost 0 10800 604800 30"
      soa_record.ttl = 300
      soa_record.save
    end

    def bind_instance_vms
      unbound_instances = []

      @deployment_plan.jobs.each do |job|
        job.instances.each do |instance_spec|
          # Don't allocate resource pool VMs to instances in detached state
          next if instance_spec.state == "detached"
          # Skip bound instances
          next if instance_spec.instance.vm
          unbound_instances << instance_spec
        end
      end

      return if unbound_instances.empty?

      @event_log.begin_stage("Binding instance VMs", unbound_instances.size)

      ThreadPool.new(:max_threads => 32).wrap do |pool|
        unbound_instances.each do |instance_spec|
          instance = instance_spec.instance
          job      = instance_spec.job
          idle_vm  = instance_spec.idle_vm

          instance.update(:vm => idle_vm.vm)

          pool.process do
            @event_log.track("#{job.name}/#{instance.index}") do

              # Apply the assignment to the VM
              state = idle_vm.current_state
              state["job"] = job.spec
              state["index"] = instance.index
              state["release"] = @deployment_plan.release.spec

              idle_vm.vm.update(:apply_spec => state)

              agent = AgentClient.new(idle_vm.vm.agent_id)
              agent.apply(state)
              instance_spec.current_state = state
            end
          end
        end
      end
    end

    def delete_unneeded_vms
      unneeded_vms = @deployment_plan.unneeded_vms
      return if unneeded_vms.empty?

      @event_log.begin_stage("Deleting unneeded VMs", unneeded_vms.size)

      # TODO: make pool size configurable?
      ThreadPool.new(:max_threads => 10).wrap do |pool|
        unneeded_vms.each do |vm|
          pool.process do
            @event_log.track(vm.cid) do
              @logger.info("Delete unneeded VM #{vm.cid}")
              @cloud.delete_vm(vm.cid)
              vm.destroy
            end
          end
        end
      end
    end

    def delete_unneeded_instances
      unneeded_instances = @deployment_plan.unneeded_instances
      return if unneeded_instances.empty?

      @event_log.begin_stage("Deleting unneeded instances", unneeded_instances.size)
      InstanceDeleter.new(@deployment_plan).delete_instances(unneeded_instances)
      @logger.info("Deleted no longer needed instances")
    end
  end
end
