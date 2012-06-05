# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlan
    class ResourcePoolSpec
      include ValidationHelper

      attr_accessor :name
      attr_accessor :deployment
      attr_accessor :stemcell
      attr_accessor :network
      attr_accessor :cloud_properties
      attr_accessor :env
      attr_accessor :env_hash
      attr_accessor :size
      attr_accessor :idle_vms
      attr_accessor :allocated_vms
      attr_accessor :active_vm_count

      # @param [DeploymentPlan] deployment Deployment plan
      # @param [Hash] resource_pool_spec Raw resource pool spec from deployment
      #   manifest
      def initialize(deployment, resource_pool_spec)
        @deployment = deployment

        @name = safe_property(resource_pool_spec, "name", :class => String)
        @size = safe_property(resource_pool_spec, "size", :class => Integer)

        @cloud_properties = safe_property(resource_pool_spec,
                                          "cloud_properties", :class => Hash)

        stemcell_property = safe_property(resource_pool_spec, "stemcell",
                                          :class => Hash)
        @stemcell = StemcellSpec.new(self, stemcell_property)

        network_name = safe_property(resource_pool_spec, "network",
                                     :class => String)
        @network = @deployment.network(network_name)

        if @network.nil?
          raise ResourcePoolSpecUnknownNetwork,
                "Resource pool `#{@name}' references " +
                "an unknown network `#{network_name}'"
        end

        @env = safe_property(resource_pool_spec, "env",
                             :class => Hash, :optional => true) || {}
        @env_hash = Digest::SHA1.hexdigest(Yajl::Encoder.encode(@env.sort))

        @idle_vms = []
        @allocated_vms = []
        @active_vm_count = 0
        @reserved_vm_count = 0
      end

      def missing_vm_count
        @size - @active_vm_count - @idle_vms.size
      end

      def add_idle_vm
        idle_vm = IdleVm.new(self)
        @idle_vms << idle_vm
        idle_vm
      end

      def mark_active_vm
        @active_vm_count += 1
      end

      def reserve_vm
        @reserved_vm_count += 1
        if @reserved_vm_count > @size
          raise ResourcePoolSpecNotEnoughCapacity,
                "Resource pool `#{@name}' is not big enough: " +
                "#{@reserved_vm_count} VMs needed, capacity is #{@size}"
        end
      end

      def allocate_vm
        allocated_vm = @idle_vms.pop
        @allocated_vms << allocated_vm
        allocated_vm
      end

      def spec
        {
            "name" => @name,
            "cloud_properties" => @cloud_properties,
            "stemcell" => @stemcell.spec
        }
      end
    end
  end
end