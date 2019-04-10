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
        reconciled_reservations = []

        existing_reservations.each do |existing_reservation|
          next unless existing_reservation.reserved?

          # can't reuse a reservation if it switches az
          if az_does_not_match_and_cant_be_ignored(existing_reservation, @instance_plan.desired_instance.az)
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

          if desired_reservation
            @logger.debug(
              "For desired reservation #{desired_reservation} found existing reservation " \
              "on the same network #{existing_reservation}",
            )

            if both_are_dynamic_reservations(existing_reservation, desired_reservation) ||
               both_are_static_reservations_with_same_ip(existing_reservation, desired_reservation) ||
               both_are_vip_reservations(existing_reservation, desired_reservation)

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
              reconciled_reservations << desired_reservations.delete(desired_reservation)
            else
              @logger.debug("Can't reuse reservation #{existing_reservation} for #{desired_reservation}")
            end
          else
            @logger.debug("Unneeded reservation #{existing_reservation}")
          end
        end

        if @instance_plan.should_create_swap_delete? &&
           (@instance_plan.recreate_for_non_network_reasons? ||
            network_allocations_changed?(desired_reservations, unplaced_existing_reservations))
          unplaced_existing_reservations += existing_network_plans.map(&:reservation)
          reconciled_reservations.each do |reservation|
            desired_reservations << reservation
          end
          existing_network_plans = []
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

        return false if desired_reservation.network.is_a?(DynamicNetwork) || existing_reservation.network.is_a?(DynamicNetwork)

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

      def both_are_vip_reservations(existing_reservation, desired_reservation)
        existing_reservation.network.vip? && desired_reservation.network.vip?
      end

      def az_does_not_match_and_cant_be_ignored(existing_reservation, desired_az)
        existing_ip_az_names = if existing_reservation.network.vip? && !existing_reservation.network.globally_allocate_ip?
                                 [existing_reservation.instance_model.availability_zone].compact
                               else
                                 existing_reservation.network.find_az_names_for_ip(existing_reservation.ip).to_a.compact
                               end

        @logger.debug("Existing reservation belongs to azs: #{existing_ip_az_names}, desired az is #{desired_az}")

        return false if existing_ip_az_names.empty? && desired_az.nil?
        return true if desired_az.nil?

        !existing_ip_az_names.include?(desired_az.name)
      end

      def network_allocations_changed?(desired_reservations, unplaced_existing_reservations)
        desired_reservations.length.positive? || unplaced_existing_reservations.length.positive?
      end
    end
  end
end
