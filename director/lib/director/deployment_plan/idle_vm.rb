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
      # @return [DeploymentPlan::ResourcePool] associated resource pool
      attr_reader :resource_pool

      # @return [NetworkReservation] VM network reservation
      attr_accessor :network_reservation

      # @return [Models::Vm] associated model
      attr_accessor :vm

      # @return [Hash] current state as provided by the BOSH Agent
      attr_accessor :current_state

      # @return [InstanceSpec, nil] instance that reserved this VM
      # @todo rename to reserved_instance
      attr_accessor :bound_instance

      ##
      # Creates a new idle VM reference for the specific resource pool
      # @param [DeploymentPlan::ResourcePool] resource_pool Resource pool
      def initialize(resource_pool)
        @resource_pool = resource_pool
        @current_state = nil
        @bound_instance = nil
        @network_reservation = nil
        @vm = nil
      end

      #
      # @return [Boolean] Does this VM have a network reservation?
      def has_network_reservation?
        !@network_reservation.nil?
      end

      #
      # Uses provided network reservation
      # @param [NetworkReservation] reservation Network reservation
      def use_reservation(reservation)
        @network_reservation = reservation
      end

      ##
      # @return [Hash] BOSH network settings used for Agent apply call
      def network_settings
        # use the instance network settings if bound, otherwise use the one
        # provided by the resource pool
        if @bound_instance
          @bound_instance.network_settings
        else
          unless @network_reservation
            raise NetworkReservationMissing,
                  "Missing network reservation for resource pool VM"
          end

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
            resource_pool.deployment_plan.recreate
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