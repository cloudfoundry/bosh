module Bosh::Director
  class VmReuser
    def initialize
      @stemcells_to_vms = {}
    end

    def add_vm(reservation, vm, stemcell, network_settings)
      vm_d = VmData.new(reservation, vm, stemcell, network_settings)
      @stemcells_to_vms[stemcell] ||= []
      @stemcells_to_vms[stemcell] << vm_d
      vm_d.mark_in_use
      vm_d
    end

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

    def get_num_vms(stemcell)
      return @stemcells_to_vms[stemcell].nil? ?
          0 : @stemcells_to_vms[stemcell].size
    end

    def each
      @stemcells_to_vms.each do |stemcell, vms|
        vms.each do |vm|
          yield(vm)
        end
      end
    end

  #  todo make a delete and a delete all
  end

  class VmData
    attr_accessor :reservation
    attr_accessor :vm
    attr_accessor :stemcell
    attr_accessor :network_settings
    attr_accessor :agent_id
    attr_accessor :agent

    def initialize(reservation, vm, stemcell, network_settings)
      @reservation = reservation
      @vm = vm
      @stemcell = stemcell
      @network_settings = network_settings
      @being_used = false
      @being_used_mutex = Mutex.new
    end

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

    def release
      @being_used_mutex.synchronize do
        @being_used = false
      end
    end
  end
end
