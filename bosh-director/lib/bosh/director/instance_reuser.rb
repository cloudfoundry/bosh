module Bosh::Director
  class NilInstanceError < ArgumentError; end

  # A class for maintaining Instance objects, making reusing Instances easier.
  class InstanceReuser
    def initialize
      @idle_instances_by_stemcell = {}
      @in_use_instances_by_stemcell = {}
      @mutex = Mutex.new
    end

    # Adds an instance's information to the pool of VMs that can be reused.
    # @param [DeploymentPlan::Instance] The instance for the new VM.
    def add_in_use_instance(instance, stemcell)
      raise NilInstanceError if instance.nil?
      @mutex.synchronize do
        @in_use_instances_by_stemcell[stemcell] ||= []
        @in_use_instances_by_stemcell[stemcell] << instance
      end
    end

    # Returns the instance of a VM that is not in use and can be reused.
    # @param [Models::Stemcell] stemcell The stemcell that the VM must be running.
    # @return [DeploymentPlan::Instance] The instance for an existing unused VM, if one exists. Otherwise, nil.
    def get_instance(stemcell)
      @mutex.synchronize do
        return nil if @idle_instances_by_stemcell[stemcell].nil?
        instance = @idle_instances_by_stemcell[stemcell].pop
        return nil if instance.nil?
        @in_use_instances_by_stemcell[stemcell] ||= []
        @in_use_instances_by_stemcell[stemcell] << instance
        return instance
      end
    end

    def release_instance(instance)
      raise NilInstanceError if instance.nil?
      @mutex.synchronize do
        release_without_lock(instance)
      end
    end

    def remove_instance(instance)
      raise NilInstanceError if instance.nil?
      @mutex.synchronize do
        release_without_lock(instance)
        @idle_instances_by_stemcell.each_value do |vms|
          vms.each do |v|
            vms.delete(v) if instance == v
          end
        end
      end
    end

    # Gets the total number of compilation instances created with a given stemcell.
    # @param [Models::Stemcell] stemcell The stemcell the VMs are running.
    # @return [Integer] The number of instances running a given stemcell.
    def get_num_instances(stemcell)
      @mutex.synchronize do
        idle_count = @idle_instances_by_stemcell[stemcell].nil? ? 0 : @idle_instances_by_stemcell[stemcell].size
        in_use_count = @in_use_instances_by_stemcell[stemcell].nil? ? 0 : @in_use_instances_by_stemcell[stemcell].size
        idle_count + in_use_count
      end
    end

    # An iterator for all compilation VMs on all stemcells.
    # @yield [DeploymentPlan::Instance] yields each instance in InstanceReuser.
    def each
      all_vms = (@idle_instances_by_stemcell.values + @in_use_instances_by_stemcell.values).flatten
      all_vms.each do |vm|
        yield vm
      end
    end

    private

    def release_without_lock(instance)
      @in_use_instances_by_stemcell.each do |stemcell, vms|
        vms.each do |v|
          if instance == v
            vms.delete(v)
            @idle_instances_by_stemcell[stemcell] ||= []
            @idle_instances_by_stemcell[stemcell] << instance
          end
        end
      end
    end
  end
end
