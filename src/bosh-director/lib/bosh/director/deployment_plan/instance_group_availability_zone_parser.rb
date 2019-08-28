module Bosh::Director
  module DeploymentPlan
    class InstanceGroupAvailabilityZoneParser
      include ValidationHelper

      def parse(instance_group_spec, instance_group_name, deployment, networks)
        az_names = safe_property(instance_group_spec, 'azs', class: Array, optional: true)
        check_contains(az_names, networks, instance_group_name)

        return nil if az_names.nil?

        check_validity_of(az_names, instance_group_name)
        look_up_from_deployment(az_names, deployment, instance_group_name)
      end

      def check_contains(az_names, networks, instance_group_name)
        networks.each do |network|
          next if network.has_azs?(az_names)

          raise JobNetworkMissingRequiredAvailabilityZone,
                "Instance group '#{instance_group_name}' must specify availability zone" \
                " that matches availability zones of network '#{network.name}'"
        end
      end

      def check_validity_of(az_names, instance_group_name)
        if az_names.empty?
          raise JobMissingAvailabilityZones, "Instance group '#{instance_group_name}' has empty availability zones"
        end

        az_names.each do |name|
          unless name.is_a?(String)
            raise JobInvalidAvailabilityZone, "Instance group '#{instance_group_name}' has invalid" \
                  " availability zone '#{name}', string expected"
          end
        end
      end

      def look_up_from_deployment(az_names, deployment, instance_group_name)
        az_names.map do |name|
          az = deployment.availability_zone(name)
          if az.nil?
            raise JobUnknownAvailabilityZone, "Instance group '#{instance_group_name}'" \
                  " references unknown availability zone '#{name}'"
          end
          az
        end
      end
    end
  end
end
