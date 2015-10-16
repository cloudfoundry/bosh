module Bosh::Director::DeploymentPlan
  module NetworkPlanner
    class ReservationReconciler
      def initialize(logger)
        @logger = logger
      end

      def reconcile(desired_reservations, existing_reservations)
        unplaced_existing_reservations = Set.new(existing_reservations)
        existing_network_plans = []
        desired_network_plans = desired_reservations.map do |reservation|
          Plan.new(reservation: reservation)
        end

        existing_reservations.each do |existing_reservation|
          desired_reservation = desired_reservations.find { |ip| ip.network == existing_reservation.network }

          if desired_reservation && existing_reservation.reserved?
            @logger.debug("For desired reservation #{desired_reservation} found existing reservation on the same network #{existing_reservation}")

            if both_are_dynamic_reservations(existing_reservation, desired_reservation) ||
              both_are_static_reservations_with_same_ip(existing_reservation, desired_reservation)

              @logger.debug("Reusing existing reservation #{existing_reservation} for '#{desired_reservation}'")
              existing_network_plans << Plan.new(reservation: existing_reservation, existing: true)
              unplaced_existing_reservations.delete(existing_reservation)
              desired_network_plans.delete_if { |plan| plan.reservation == desired_reservation }
            else
              @logger.debug("Can't reuse reservation #{existing_reservation} for #{desired_reservation}")
            end
          else
            @logger.debug("Unneeded reservation #{existing_reservation}")
          end
        end

        obsolete_network_plans = unplaced_existing_reservations.map do |reservation|
          Plan.new(reservation: reservation, obsolete: true)
        end

        existing_network_plans + desired_network_plans + obsolete_network_plans
      end

      private

      def both_are_dynamic_reservations(existing_reservation, reservation)
        existing_reservation.type == reservation.type &&
          reservation.dynamic?
      end

      def both_are_static_reservations_with_same_ip(existing_reservation, reservation)
        existing_reservation.type == reservation.type &&
          reservation.static? &&
          reservation.ip == existing_reservation.ip
      end
    end
  end
end
