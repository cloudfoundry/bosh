# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class ResourcePoolUpdater

    def initialize(resource_pool)
      @resource_pool = resource_pool
      @cloud = Config.cloud
      @logger = Config.logger
      @event_log = Config.event_log
    end

    ##
    # Creates VMs that are considered missing from the deployment
    #
    # @param [ThreadPool] thread_pool Thread pool that will be used to
    #   parallelize the operation
    # @yield [idle_vm] filter for which missing VMs to create
    def create_missing_vms(thread_pool)
      counter = 0
      vms_to_process = []

      each_idle_vm do |idle_vm|
        next if idle_vm.vm
        if !block_given? || yield(idle_vm)
          counter += 1
          vms_to_process << idle_vm
        end
      end

      @logger.info("Creating #{counter} missing VMs")
      vms_to_process.each_with_index do |idle_vm, index|
        thread_pool.process do
          @event_log.track("#{@resource_pool.name}/#{index}") do
            with_thread_name("create_missing_vm(#{@resource_pool.name}, #{index}/#{counter})") do
              @logger.info("Creating missing VM")
              create_missing_vm(idle_vm)
            end
          end
        end
      end
    end

    # Creates missing VMs that have bound instances
    # (as opposed to missing resource pool VMs)
    def create_bound_missing_vms(thread_pool)
      create_missing_vms(thread_pool) { |idle_vm| !idle_vm.bound_instance.nil? }
    end

    def create_missing_vm(idle_vm)
      deployment = @resource_pool.deployment.deployment
      stemcell = @resource_pool.stemcell.stemcell

      vm = VmCreator.new.create(deployment, stemcell, @resource_pool.cloud_properties,
                                idle_vm.network_settings, nil, @resource_pool.env)

      # TODO: delete the VM if it wasn't saved
      agent = AgentClient.new(vm.agent_id)
      agent.wait_until_ready

      update_state(agent, vm, idle_vm)

      idle_vm.vm = vm
      idle_vm.current_state = agent.get_state
    rescue Exception => e
      @logger.info("Cleaning up the created VM due to an error: #{e}")
      begin
        @cloud.delete_vm(vm.cid) if vm && vm.cid
        vm.destroy if vm && vm.id
      rescue Exception
        @logger.info("Could not cleanup VM: #{vm.cid}") if vm
      end
      raise e
    end

    def update_state(agent, vm, idle_vm)
      state = {
          "deployment" => @resource_pool.deployment.name,
          "resource_pool" => @resource_pool.spec,
          "networks" => idle_vm.network_settings
      }

      # apply the instance state if it's already bound so we can recover if needed
      if idle_vm.bound_instance
        instance_spec = idle_vm.bound_instance.spec
        %w(job index release).each { |key| state[key] = instance_spec[key] }
      end

      vm.update(:apply_spec => state)
      agent.apply(state)
    end

    # Deletes extra VMs in a resource pool
    # @param thread_pool Thread pool used to parallelize delete operations
    def delete_extra_vms(thread_pool)
      count = extra_vm_count
      @logger.info("Deleting #{count} extra VMs")

      count.times do
        idle_vm = @resource_pool.idle_vms.shift
        vm_cid = idle_vm.vm.cid

        thread_pool.process do
          @event_log.track("#{@resource_pool.name}/#{vm_cid}") do
            @logger.info("Deleting extra VM: #{vm_cid}")
            @cloud.delete_vm(vm_cid)
            idle_vm.vm.destroy
          end
        end
      end
    end

    def delete_outdated_idle_vms(thread_pool)
      count = outdated_idle_vm_count
      index = 0
      index_lock = Mutex.new

      @logger.info("Deleting #{count} outdated idle VMs")

      @resource_pool.idle_vms.each do |idle_vm|
        next unless idle_vm.vm && idle_vm.changed?
        vm_cid = idle_vm.vm.cid

        thread_pool.process do
          @event_log.track("#{@resource_pool.name}/#{vm_cid}") do
            index_lock.synchronize { index += 1 }

            with_thread_name("delete_outdated_vm(#{@resource_pool.name}, #{index - 1}/#{count})") do
              @logger.info("Deleting outdated VM: #{vm_cid}")
              @cloud.delete_vm(vm_cid)
              vm = idle_vm.vm
              idle_vm.vm = nil
              idle_vm.current_state = nil
              vm.destroy
            end
          end
        end
      end
    end

    # Attempts to allocate a dynamic IP address for all idle VMs
    # (unless they already have one). This allows us to fail earlier
    # in case any of resource pools is not big enough to accommodate
    # those VMs.
    def reserve_networks
      network = @resource_pool.network

      each_idle_vm do |idle_vm|
        unless idle_vm.network_reservation
          reservation = NetworkReservation.new(
              :type => NetworkReservation::DYNAMIC)
          network.reserve(reservation)

          unless reservation.reserved?
            case reservation.error
              when NetworkReservation::CAPACITY
                raise NetworkReservationNotEnoughCapacity,
                      "`#{name}/#{index}' asked for a dynamic IP " +
                      "but there were no more available"
              else
                raise NetworkReservationError,
                      "`#{name}/#{index}' failed to reserve " +
                      "dynamic IP: #{reservation.error}"
            end
          end

          idle_vm.network_reservation = reservation
        end
      end
    end

    def generate_agent_id
      UUIDTools::UUID.random_create.to_s
    end

    def each_idle_vm
      @resource_pool.allocated_vms.each { |idle_vm| yield idle_vm }
      @resource_pool.idle_vms.each { |idle_vm| yield idle_vm }
    end

    def each_idle_vm_with_index
      index = 0
      each_idle_vm do |idle_vm|
        yield(idle_vm, index)
        index += 1
      end
    end

    def extra_vm_count
      @resource_pool.active_vm_count +
          @resource_pool.idle_vms.size +
          @resource_pool.allocated_vms.size -
          @resource_pool.size
    end

    def outdated_idle_vm_count
      counter = 0
      @resource_pool.idle_vms.each do |idle_vm|
        counter += 1 if idle_vm.vm && idle_vm.changed?
      end
      counter
    end

    def missing_vm_count
      counter = 0
      each_idle_vm do |idle_vm|
        next if idle_vm.vm
        counter += 1
      end
      counter
    end

    def bound_missing_vm_count
      counter = 0
      each_idle_vm do |idle_vm|
        next if idle_vm.vm
        next if idle_vm.bound_instance.nil?
        counter += 1
      end
      counter
    end
  end
end
