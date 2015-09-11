module Bosh::Director::DeploymentPlan
  class NetworkPlan
    def initialize(attrs)
      @reservation = attrs.fetch(:reservation)
      @obsolete = attrs.fetch(:obsolete, false)
    end

    attr_reader :reservation

    def obsolete?
      !!@obsolete
    end
  end

  class NetworkPlanner
    def initialize(logger)
      @logger = logger
    end

    def plan_ips(desired_reservations, existing_reservations)
      unplaced_existing_reservations = Set.new(existing_reservations)

      existing_reservations.each do |existing_reservation|
        reservation = desired_reservations.find { |ip| ip.network == existing_reservation.network }
        if reservation
          @logger.debug("existing reservation #{existing_reservation} is still needed by #{reservation}")
          # TODO: we should be associating the existing reservation with the network plan
          # this will also let us easily tell which are 'new' and stop 'unless reservation.reserved?'ing
          reservation.bind_existing(existing_reservation)
          if reservation.reserved?
            @logger.debug("Found matching existing reservation #{existing_reservation} for `#{self}'")
            unplaced_existing_reservations.delete(existing_reservation)
          end
        else
          @logger.debug("unneeded reservation #{existing_reservation}")
        end
      end

      obsolete_network_plans = unplaced_existing_reservations.map do |reservation|
        NetworkPlan.new(reservation: reservation, obsolete: true)
      end

      desired_network_plans = desired_reservations.map do |reservation|
        NetworkPlan.new(reservation: reservation, obsolete: false)
      end

      desired_network_plans + obsolete_network_plans
    end
  end
end
