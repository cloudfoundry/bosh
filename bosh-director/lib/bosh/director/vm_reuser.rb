module Bosh::Director
  class NilVMDataError < ArgumentError
  end

  # A class for maintaining VmData objects, making reusing VMs easier.
  class VmReuser
    def initialize
      @idle_vms_by_stemcell = {}
      @in_use_vms_by_stemcell = {}
      @mutex = Mutex.new
    end

    # Adds a VM's information to the pool of VMs that can be reused.
    # @param [VmData] The VmData instance for the new VM.
    def add_vm(vm_data)
      raise NilVMDataError if vm_data.nil?
      @mutex.synchronize do
        @idle_vms_by_stemcell[vm_data.stemcell] ||= []
        @idle_vms_by_stemcell[vm_data.stemcell] << vm_data
      end
    end

    # Returns the VmData instance of a VM that is not in use and can be reused.
    # @param [Models::Stemcell] stemcell The stemcell that the VM must be running.
    # @return [VmData?] The VmData instance for an existing unused VM, if one exists. Otherwise, nil.
    def get_vm(stemcell)
      @mutex.synchronize do
        return nil if @idle_vms_by_stemcell[stemcell].nil?
        vm_data = @idle_vms_by_stemcell[stemcell].pop
        return nil if vm_data.nil?
        @in_use_vms_by_stemcell[stemcell] ||= []
        @in_use_vms_by_stemcell[stemcell] << vm_data
        return vm_data
      end
    end

    def release_vm(vm_data)
      raise NilVMDataError if vm_data.nil?
      @mutex.synchronize do
        release_without_lock(vm_data)
      end
    end

    def remove_vm(vm_data)
      raise NilVMDataError if vm_data.nil?
      @mutex.synchronize do
        release_without_lock(vm_data)
        @idle_vms_by_stemcell.each_value do |vms|
          vms.each do |v|
            vms.delete(v) if vm_data == v
          end
        end
      end
    end

    # Gets the total number of compilation VMs created with a given stemcell.
    # @param [Models::Stemcell] stemcell The stemcell the VMs are running.
    # @return [Integer] The number of VMs running a given stemcell.
    def get_num_vms(stemcell)
      @mutex.synchronize do
        @idle_vms_by_stemcell[stemcell].nil? ? 0 : @idle_vms_by_stemcell[stemcell].size
      end
    end

    # An iterator for all compilation VMs on all stemcells.
    # @yield [VmData] Yields each VM in VmReuser.
    def each
      @idle_vms_by_stemcell.each do |stemcell, vms|
        vms.each do |vm|
          yield vm
        end
      end
    end

    private

    def release_without_lock(vm_data)
      @in_use_vms_by_stemcell.each do |stemcell,vms|
        vms.each do |v|
          if vm_data == v
            vms.delete(v)
            @idle_vms_by_stemcell[stemcell] << vm_data
          end
        end
      end
    end
  end

end
