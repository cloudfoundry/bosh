module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        class StaticIpsAvailabilityZonePicker
          include IpUtil

          def initialize(instance_plan_factory, network_planner, job_networks, job_name, desired_azs, logger)
            @instance_plan_factory = instance_plan_factory
            @network_planner = network_planner
            @job_networks = job_networks
            @job_name = job_name
            @networks_to_static_ips = NetworksToStaticIps.create(@job_networks, desired_azs, job_name)
            @desired_azs = desired_azs
            @logger = logger
          end

          def place_and_match_in(desired_instances, existing_instance_models)
            @networks_to_static_ips.validate_azs_are_declared_in_job_and_subnets(@desired_azs)
            @networks_to_static_ips.validate_ips_are_in_desired_azs(@desired_azs)
            validate_ignored_instances_networks(existing_instance_models)

            desired_instances = desired_instances.dup

            instance_plans = place_existing_instance_plans(desired_instances, existing_instance_models)
            instance_plans = place_new_instance_plans(desired_instances, instance_plans)

            if ignored_instances_are_obsolete?(instance_plans)
              raise DeploymentIgnoredInstancesModification, "In instance group '#{@job_name}', an attempt was made to remove a static ip"+
                  ' that is used by an ignored instance. This operation is not allowed.'
            end

            instance_plans
          end

          private

          def validate_ignored_instances_networks(existing_instance_models)
            existing_instance_models.each do |existing_instance_model|
              next if !existing_instance_model.ignore

              # Validate that no networks were added or deleted
              desired_networks_names = @job_networks.map(&:name).uniq.sort
              existing_networks_names = existing_instance_model.ip_addresses.map(&:network_name).uniq.sort

              if desired_networks_names != existing_networks_names
                raise DeploymentIgnoredInstancesModification, "In instance group '#{@job_name}', which contains ignored vms,"+
                    ' an attempt was made to modify the networks. This operation is not allowed.'
              end

              # Validate that no ip addresses, that were assigned to an ignored VM, have been removed
              existing_instance_model.ip_addresses.each do |ip_address|
                ignored_vm_network = @job_networks.select { |n| n.name == ip_address.network_name }.first

                if !ignored_vm_network.static_ips.include?(ip_address.address)
                  raise DeploymentIgnoredInstancesModification, "In instance group '#{@job_name}', an attempt was made to remove a static ip"+
                      ' that is used by an ignored instance. This operation is not allowed.'
                end
              end
            end
          end

          def place_existing_instance_plans(desired_instances, existing_instance_models)
            instance_plans = []
            # create existing instance plans with network plans that use specified static IPs
            existing_instance_models.each do |existing_instance_model|
              instance_plan = create_instance_plan_based_on_existing_ips(desired_instances, existing_instance_model)
              instance_plans << instance_plan if instance_plan
            end

            # create the rest existing instance plans
            existing_instance_models.each do |existing_instance_model|
              unless already_has_instance_plan?(existing_instance_model, instance_plans)
                instance_plans << create_existing_instance_plan_with_az_validation(desired_instances, instance_plans, existing_instance_model)
              end
            end

            # fulfill missing network plans
            instance_plans.reject(&:obsolete?).each do |instance_plan|
              @job_networks.each do |network|
                unless network.static?
                  instance_plan.network_plans << @network_planner.network_plan_with_dynamic_reservation(instance_plan, network)
                  next
                end

                unless instance_plan.network_plan_for_network(network.deployment_network)
                  instance_plan.network_plans << create_network_plan_with_az(instance_plan, network, instance_plans)
                end
              end
            end

            instance_plans
          end

          def place_new_instance_plans(desired_instances, instance_plans)
            @networks_to_static_ips.distribute_evenly_per_zone

            desired_instances.each do |desired_instance|
              instance_plan = @instance_plan_factory.desired_new_instance_plan(desired_instance)
              @job_networks.each do |network|
                unless network.static?
                  instance_plan.network_plans << @network_planner.network_plan_with_dynamic_reservation(instance_plan, network)
                  next
                end

                instance_plan.network_plans << create_network_plan_with_az(instance_plan, network, instance_plans)
              end

              instance_plans << instance_plan
            end

            instance_plans
          end

          def create_network_plan_with_az(instance_plan, network, instance_plans)
            desired_instance = instance_plan.desired_instance
            instance = instance_plan.instance
            if desired_instance.az.nil?
              static_ip_to_azs = @networks_to_static_ips.next_ip_for_network(network)
              if static_ip_to_azs.az_names.size == 1
                az_name = static_ip_to_azs.az_names.first
                @logger.debug("Assigning az '#{az_name}' to instance '#{instance}'")
              else
                az_name = find_az_name_with_least_number_of_instances(static_ip_to_azs.az_names, instance_plans)
                @logger.debug("Assigning az '#{az_name}' to instance '#{instance}' based on least number of instances")
              end
              desired_instance.az = to_az(az_name)
            else
              static_ip_to_azs = @networks_to_static_ips.find_by_network_and_az(network, desired_instance.availability_zone)
            end
            if static_ip_to_azs.nil?
              raise Bosh::Director::NetworkReservationError,
                    'Failed to distribute static IPs to satisfy existing instance reservations'
            end

            @logger.debug("Claiming IP '#{format_ip(static_ip_to_azs.ip)}' on network #{network.name} and az '#{desired_instance.availability_zone}' for instance '#{instance}'")
            @networks_to_static_ips.claim_in_az(static_ip_to_azs.ip, desired_instance.availability_zone)

            @network_planner.network_plan_with_static_reservation(instance_plan, network, static_ip_to_azs.ip)
          end

          def create_instance_plan_based_on_existing_ips(desired_instances, existing_instance_model)
            instance_plan = nil

            @job_networks.each do |network|
              next unless network.static?
              instance_ips_on_network = find_instance_ips_on_network(existing_instance_model, network)
              network_plan = nil

              instance_ips_on_network.each do |instance_ip|
                ip_address = instance_ip.address.to_i

                # Instance is using IP in static IPs list, we have to use this instance
                @logger.debug("Existing instance '#{instance_name(existing_instance_model)}' is using static IP '#{format_ip(ip_address)}' on network '#{network.name}'")
                if instance_plan.nil?
                  desired_instance = desired_instances.shift
                  instance_plan = create_existing_instance_plan_with_az(desired_instance, existing_instance_model, network, ip_address)
                  instance_plan
                end

                if network_plan.nil? && instance_plan.desired_instance
                  create_network_plan_with_ip(instance_plan, network, ip_address)
                end

                if instance_plan.desired_instance.nil?
                  # delete so that other instances not reusing ips of existing instance
                  # obsolete instances should not affect distribution
                  @networks_to_static_ips.delete(ip_address)
                else
                  # put ip in az where existing instance is so that
                  # during distribution it will be taken into account
                  @networks_to_static_ips.claim_in_az(ip_address, instance_plan.desired_instance.availability_zone)
                end
              end
            end

            instance_plan
          end

          def find_instance_ips_on_network(existing_instance_model, network)
            existing_instance_model.ip_addresses.select { |ip_address| network.static_ips.include?(ip_address.address) }
          end

          def already_has_instance_plan?(existing_instance_model, instance_plans)
            instance_plans.map(&:existing_instance).include?(existing_instance_model)
          end

          def create_existing_instance_plan_with_az(desired_instance, existing_instance_model, network, ip_address)
            instance_plan = create_existing_instance_plan(desired_instance, existing_instance_model)
            unless instance_plan.obsolete?
              assign_az_based_on_ip(desired_instance, existing_instance_model, network, ip_address)
            end
            instance_plan
          end

          def assign_az_based_on_ip(desired_instance, existing_instance_model, network, ip_address)
            ip_az_names = @networks_to_static_ips.find_by_network_and_ip(network, ip_address.to_i).az_names

            if ip_az_names.include?(existing_instance_model.availability_zone)
              az_name = existing_instance_model.availability_zone
              @logger.debug("Instance '#{instance_name(existing_instance_model)}' belongs to az '#{az_name}' that is in subnet az list, reusing instance az.")
            else
              raise Bosh::Director::NetworkReservationError,
                "Existing instance '#{instance_name(existing_instance_model)}' is using IP '#{format_ip(ip_address)}' in availability zone '#{existing_instance_model.availability_zone}'"
            end
            desired_instance.az = to_az(az_name)
          end

          def create_existing_instance_plan_with_az_validation(desired_instances, instance_plans, existing_instance_model)
            if desired_instances.empty?
              @logger.debug("Marking instance '#{instance_name(existing_instance_model)}' as obsolete")
              @instance_plan_factory.obsolete_instance_plan(existing_instance_model)
            else
              # we can only reuse an instance if its AZ contains enough IPs for its networks

              instance_az_name = existing_instance_model.availability_zone
              @job_networks.each do |network|
                next unless network.static?
                static_ip_to_azs = @networks_to_static_ips.find_by_network_and_az(network, instance_az_name)
                if static_ip_to_azs.nil?
                  @logger.debug("Marking instance '#{instance_name(existing_instance_model)}' as obsolete, not enough IPs in instance az")
                  return @instance_plan_factory.obsolete_instance_plan(existing_instance_model)
                end
              end

              # we have enough IPs to fit an instance in its AZ
              @logger.debug("Reusing instance '#{instance_name(existing_instance_model)}' with new IPs")
              desired_instance = desired_instances.shift
              desired_instance.az = to_az(instance_az_name)
              instance_plan = @instance_plan_factory.desired_existing_instance_plan(existing_instance_model, desired_instance)
              @job_networks.each do |network|
                next unless network.static?
                instance_plan.network_plans << create_network_plan_with_az(instance_plan, network, instance_plans)
              end

              instance_plan
            end
          end

          def create_existing_instance_plan(desired_instance, existing_instance_model)
            if desired_instance.nil?
              # potentially a code path that never happens. It had been sending 2 for 1 which should have EXPLODED!!!
              @instance_plan_factory.obsolete_instance_plan(existing_instance_model)
            else
              @instance_plan_factory.desired_existing_instance_plan(existing_instance_model, desired_instance)
            end
          end

          def create_network_plan_with_ip(instance_plan, network, ip_address)
            instance_az = instance_plan.desired_instance.az
            instance_az_name = instance_az.nil? ? nil : instance_az.name

            ip_az_names = @networks_to_static_ips.find_by_network_and_ip(network, ip_address).az_names
            if ip_az_names.include?(instance_az_name)
              instance_plan.network_plans << @network_planner.network_plan_with_static_reservation(instance_plan, network, ip_address)
            end
          end

          def find_az_name_with_least_number_of_instances(az_names, instance_plans)
            az_names.sort_by do |az_name|
              instance_plans.select { |instance_plan| instance_plan.desired_instance.availability_zone == az_name }.size
            end.first
          end

          def to_az(az_name)
            @desired_azs.to_a.find { |az| az.name == az_name }
          end

          def instance_name(existing_instance_model)
            "#{existing_instance_model.job}/#{existing_instance_model.index}"
          end

          def ignored_instances_are_obsolete?(instance_plans)
            instance_plans.select{ |i| i.obsolete? && i.should_be_ignored? }.any?
          end
        end
      end
    end
  end
end
