module Bosh::Director::DeploymentPlan
  class NetworkPlan
    def initialize(attrs)
      @reservation = attrs.fetch(:reservation)
      @obsolete = attrs.fetch(:obsolete, false)
      @existing = attrs.fetch(:existing, false)
    end

    attr_reader :reservation

    def obsolete?
      !!@obsolete
    end

    def existing?
      !!@existing
    end
  end

  class NetworkPlanner
    def initialize(logger)
      @logger = logger
    end

    def plan_ips(desired_reservations, existing_reservations)
      unplaced_existing_reservations = Set.new(existing_reservations)
      existing_network_plans = []

      existing_reservations.each do |existing_reservation|
        reservation = desired_reservations.find { |ip| ip.network == existing_reservation.network }
        if reservation && existing_reservation.reserved?
          @logger.debug("Existing reservation #{existing_reservation} is still needed by #{reservation}")

          if both_are_dynamic_reservations(existing_reservation, reservation) ||
            both_are_static_reservations_with_same_ip(existing_reservation, reservation)
            existing_network_plans << NetworkPlan.new(reservation: existing_reservation, existing: true)
            @logger.debug("Found matching existing reservation #{existing_reservation} for '#{reservation}'")
            unplaced_existing_reservations.delete(existing_reservation)
            reservation.resolve_ip(existing_reservation.ip) if reservation.is_a?(Bosh::Director::DynamicNetworkReservation)
            reservation.mark_reserved_as(reservation.type)
          end
        else
          @logger.debug("Unneeded reservation #{existing_reservation}")
        end
      end

      obsolete_network_plans = unplaced_existing_reservations.map do |reservation|
        NetworkPlan.new(reservation: reservation, obsolete: true)
      end

      desired_network_plans = desired_reservations.map do |reservation|
        NetworkPlan.new(reservation: reservation)
      end

      existing_network_plans + desired_network_plans + obsolete_network_plans
    end

    private

    def both_are_dynamic_reservations(existing_reservation, reservation)

      existing_reservation.reserved_as.name == reservation.type.name &&
        reservation.is_a?(Bosh::Director::DynamicNetworkReservation)
    end

    def both_are_static_reservations_with_same_ip(existing_reservation, reservation)
      existing_reservation.reserved_as.name == reservation.type.name &&
        reservation.is_a?(Bosh::Director::StaticNetworkReservation) &&
        reservation.ip == existing_reservation.ip
    end
  end
end
