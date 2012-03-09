# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlan
    ##
    # Represents a resource pool VM.
    #
    # It represents a VM until it's officially bound to an instance. It can be
    # reserved for an instance to minimize the number of CPI operations
    # (network & storage) required for the VM to match the instance
    # requirements.
    #
    # @todo rename class to ResourcePoolVm
    class IdleVm
      # @return [ResourcePoolSpec] associated resource pool
      attr_accessor :resource_pool

      # @return [Hash] current state as provided by the BOSH Agent
      attr_accessor :current_state

      # @return [InstanceSpec, nil] instance that reserved this VM
      # @todo rename to reserved_instance
      attr_accessor :bound_instance

      # @return [NetworkReservation] the VM's network reservation
      attr_accessor :network_reservation

      # @return [Bosh::Director::Models::Vm] associated model
      attr_accessor :vm

      ##
      # Creates a new idle VM reference for the specific resource pool
      # @param [ResourcePoolSpec] resource_pool resource pool
      def initialize(resource_pool)
        @resource_pool = resource_pool
      end

      ##
      # @return [Hash] BOSH network settings used for Agent apply call
      def network_settings
        # use the instance network settings if bound, otherwise use the one
        # provided by the resource pool
        if @bound_instance
          @bound_instance.network_settings
        else
          raise "Missing network reservation" unless @network_reservation

          network_settings = {}
          network = @resource_pool.network
          network_settings[network.name] = network.network_settings(
              @network_reservation)
          network_settings
        end
      end

      ##
      # @return [Boolean] returns true if the expected network configuration
      #   differs from the one provided by the VM
      def networks_changed?
        network_settings != @current_state["networks"]
      end

      ##
      # @return [Boolean] returns true if the expected resource pool
      #   specification differs from the one provided by the VM
      def resource_pool_changed?
        resource_pool.spec != @current_state["resource_pool"] ||
            resource_pool.deployment.recreate
      end

      ##
      # @return [Boolean] returns true if the any of the expected specifications
      #   differ from the ones provided by the VM
      def changed?
        resource_pool_changed? || networks_changed?
      end
    end
  end
end