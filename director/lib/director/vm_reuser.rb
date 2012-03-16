module Bosh::Director
  # A class for maintaining VmData objects, making reusing VMs easier.
  class VmReuser
    def initialize
      @stemcells_to_vms = {}
    end

    # Adds a VM's information to the pool of VMs that can be reused.
    # @param [NetworkReservation] reservation The network reservation for this
    #     VM.
    # @param [Models::Vm] vm The VM to be reused.
    # @param [Models::Stemcell] stemcell The Stemcell to make the VM on.
    # @param [Hash] network_settings A hash containing the network reservation.
    # @return [VmData] The VmData instance for the new VM.
    def add_vm(reservation, vm, stemcell, network_settings)
      vm_d = VmData.new(reservation, vm, stemcell, network_settings)
      @stemcells_to_vms[stemcell] ||= []
      @stemcells_to_vms[stemcell] << vm_d
      vm_d.mark_in_use
      vm_d
    end

    # Returns the VmData instance of a VM that is not in use and can be reused.
    # @param [Models::Stemcell] stemcell The stemcell that the VM must be
    #     running.
    # @return [VmData?] The VmData instance for an existing unused VM, if one
    #     exists.  Otherwise, nil.
    def get_vm(stemcell)
      unless @stemcells_to_vms[stemcell].nil?
        @stemcells_to_vms[stemcell].each do |vm_data|
          if vm_data.mark_in_use
            return vm_data
          end
        end
      end
      return nil
    end

    # Gets the total number of compilation VMs created with a given stemcell.
    # @param [Models::Stemcell] stemcell The stemcell the VMs are running.
    # @return [Integer] The number of VMs running a given stemcell.
    def get_num_vms(stemcell)
      return @stemcells_to_vms[stemcell].nil? ?
          0 : @stemcells_to_vms[stemcell].size
    end

    # An iterator for all compilation VMs on all stemcells.
    # @yield [VmData] Yields each VM in VmReuser.
    def each
      @stemcells_to_vms.each do |stemcell, vms|
        vms.each do |vm|
          yield(vm)
        end
      end
    end

  end

  # A class for storing VMs and their associated data so that they can be
  # accessed and deleted easily.
  class VmData

    # @attr [NetworkReservation] The network reservation for this VM.
    attr_reader :reservation

    # @attr [Models::Vm] The VM.
    attr_reader :vm

    # @attr[Models::Stemcell] The Stemcell this VM is running.
    attr_reader :stemcell

    # @attr [Hash] A hash containing the network reservation.
    attr_reader :network_settings

    # @attr [Integer] The agent ID running on this VM.
    attr_reader :agent_id

    # @attr [AgentClient] The agent running on this VM.
    attr_accessor :agent

    # Initializes a VmData.
    # @param [NetworkReservation] reservation The network reservation for this
    #     VM.
    # @param [Models::Vm] vm The VM to be reused.
    # @param [Models::Stemcell] stemcell The Stemcell to make the VM on.
    # @param [Hash] network_settings A hash containing the network reservation.
    def initialize(reservation, vm, stemcell, network_settings)
      @reservation = reservation
      @vm = vm
      @stemcell = stemcell
      @network_settings = network_settings
      @agent_id = vm.agent_id
      @being_used = false
      @being_used_mutex = Mutex.new
    end

    # Marks that this VM is being used.
    # @return [Boolean] Returns whether it could successfully mark this VM as in
    #     use.
    def mark_in_use
      @being_used_mutex.synchronize do
        if @being_used
          return false
        else
          @being_used = true
          return true
        end
      end
    end

    # Releases the current VM to be reused.
    def release
      @being_used_mutex.synchronize do
        @being_used = false
      end
    end
  end
end
