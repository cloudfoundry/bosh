module Bosh::Director::DeploymentPlan
  module NetworkPlanner
    class ReservationReconciler
      def initialize(instance_plan, logger)
        @instance_plan = instance_plan
        @logger = logger
      end

      def reconcile(existing_reservations)
        unplaced_existing_reservations = Set.new(existing_reservations)
        existing_network_plans = []
        desired_reservations = @instance_plan.network_plans.map(&:reservation)

        existing_reservations.each do |existing_reservation|
          unless az_is_desired(existing_reservation)
            @logger.debug(
              "Can't reuse reservation #{existing_reservation}, existing reservation az does not match " \
              "desired az '#{@instance_plan.desired_instance.availability_zone}'",
            )
            next
          end

          desired_reservation = desired_reservations.find do |reservation|
            reservation_contains_assigned_address?(existing_reservation, reservation) &&
              (reservation.dynamic? || reservation.ip == existing_reservation.ip)
          end

          if desired_reservation && existing_reservation.reserved?
            @logger.debug(
              "For desired reservation #{desired_reservation} found existing reservation " \
              "on the same network #{existing_reservation}",
            )

            if (both_are_dynamic_reservations(existing_reservation, desired_reservation) ||
                both_are_static_reservations_with_same_ip(existing_reservation, desired_reservation)) &&
               !(@instance_plan.should_hot_swap? && @instance_plan.recreate_for_non_network_reasons?)

              @logger.debug("Reusing existing reservation #{existing_reservation} for '#{desired_reservation}'")

              unplaced_existing_reservations.delete(existing_reservation)

              if existing_reservation.network != desired_reservation.network
                @logger.debug(
                  "Switching reservation from network '#{existing_reservation.network.name}' " \
                  "to '#{desired_reservation.network.name}'",
                )
                existing_reservation_ip = existing_reservation.ip

                existing_reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(
                  existing_reservation.instance_model,
                  desired_reservation.network,
                )
                existing_reservation.resolve_ip(existing_reservation_ip)
              end

              existing_network_plans << Plan.new(reservation: existing_reservation, existing: true)
              desired_reservations.delete(desired_reservation)
            else
              @logger.debug("Can't reuse reservation #{existing_reservation} for #{desired_reservation}")
            end
          else
            @logger.debug("Unneeded reservation #{existing_reservation}")
          end
        end

        desired_network_plans = desired_reservations.map do |reservation|
          Plan.new(reservation: reservation)
        end

        obsolete_network_plans = unplaced_existing_reservations.map do |reservation|
          Plan.new(reservation: reservation, obsolete: true)
        end

        existing_network_plans + desired_network_plans + obsolete_network_plans
      end

      private

      def reservation_contains_assigned_address?(existing_reservation, desired_reservation)
        return true if existing_reservation.network == desired_reservation.network
        return false unless desired_reservation.network.manual?
        return false unless existing_reservation.network.manual?

        desired_reservation.network.subnets.any? do |subnet|
          if existing_reservation.instance_model.availability_zone != '' && !subnet.availability_zone_names.nil?
            next unless subnet.availability_zone_names.include?(existing_reservation.instance_model.availability_zone)
          end

          true if subnet.is_reservable?(existing_reservation.ip)
        end
      end

      def both_are_dynamic_reservations(existing_reservation, reservation)
        existing_reservation.type == reservation.type &&
          reservation.dynamic?
      end

      def both_are_static_reservations_with_same_ip(existing_reservation, reservation)
        existing_reservation.type == reservation.type &&
          reservation.static? &&
          reservation.ip == existing_reservation.ip
      end

      def az_is_desired(existing_reservation)
        return true unless existing_reservation.network.supports_azs?

        ip_az_names = existing_reservation.network.find_az_names_for_ip(existing_reservation.ip)
        @logger.debug("Reservation #{existing_reservation} belongs to azs: #{ip_az_names}")

        desired_az = @instance_plan.desired_instance.az
        return true if ip_az_names.to_a.compact.empty? && desired_az.nil?
        return false if desired_az.nil?

        ip_az_names.to_a.include?(desired_az.name)
      end
    end
  end
end
