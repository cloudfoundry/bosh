require 'bosh/director/deployment_plan/job_network'

module Bosh::Director
  module DeploymentPlan
    class InstanceGroupNetworksParser
      include ValidationHelper
      include IpUtil

      def initialize(properties_that_require_defaults, properties_that_are_optional_defaults)
        @properties_that_require_defaults = properties_that_require_defaults
        @valid_properties = @properties_that_require_defaults | properties_that_are_optional_defaults
      end

      def parse(instance_group_spec, instance_group_name, manifest_networks)
        networks = parse_networks(instance_group_spec, instance_group_name, manifest_networks)
        networks.each do |network|
          validate_default_properties(network, instance_group_name)
        end

        validate_default_networks(networks, instance_group_name)

        networks
      end

      private

      def parse_networks(instance_group_spec, instance_group_name, manifest_networks)
        network_specs = safe_property(instance_group_spec, 'networks', class: Array)
        if network_specs.empty?
          raise JobMissingNetwork, "Instance group '#{instance_group_name}' must specify at least one network"
        end

        network_specs.map do |network_spec|
          network_name = safe_property(network_spec, 'name', class: String)
          default_for = safe_property(network_spec, 'default', class: Array, default: [])
          static_ips = parse_static_ips(network_spec['static_ips'], instance_group_name)

          deployment_network = look_up_deployment_network(manifest_networks, instance_group_name, network_name)
          deployment_network.validate_reference_from_job!(network_spec, instance_group_name)

          JobNetwork.new(network_name, static_ips, default_for, deployment_network)
        end
      end

      def look_up_deployment_network(manifest_networks, instance_group_name, network_name)
        deployment_network = manifest_networks.find { |network| network.name == network_name }
        if deployment_network.nil?
          raise JobUnknownNetwork, "Instance group '#{instance_group_name}' references an unknown network '#{network_name}'"
        end

        deployment_network
      end

      def parse_static_ips(static_ips_raw, instance_group_name)
        static_ips = nil
        if static_ips_raw
          static_ips = []
          each_ip(static_ips_raw) do |ip|
            if static_ips.include?(ip)
              raise JobInvalidStaticIPs,
                    "Instance group '#{instance_group_name}' specifies static IP '#{base_addr(ip)}' more than once"
            end

            static_ips.push(ip)
          end
        end
        static_ips
      end

      def validate_default_properties(network, instance_group_name)
        network.properties_for_which_the_network_is_the_default.each do |property|
          next if @valid_properties.include?(property)

          raise JobNetworkInvalidDefault,
                "Instance group '#{instance_group_name}' specified an invalid default network property '#{property}', " \
                'valid properties are: ' + @properties_that_require_defaults.join(', ')
        end
      end

      def validate_default_networks(networks, instance_group_name)
        networks.first.make_default_for(@properties_that_require_defaults) if networks.count == 1

        default_networks_for_properties = default_networks_for_properties(networks)
        validate_only_one_default_network(default_networks_for_properties, instance_group_name)
        validate_default_network_for_each_property(default_networks_for_properties, instance_group_name)
      end

      def validate_default_network_for_each_property(default_networks_for_properties, instance_group_name)
        missing_default_properties = default_networks_for_properties.select do |property, networks|
          is_required = @properties_that_require_defaults.include?(property)
          is_required && networks.empty?
        end.map do |property, _|
          property
        end
        return if missing_default_properties.empty?

        raise JobNetworkMissingDefault,
              "Instance group '#{instance_group_name}' must specify which network is default for " +
              missing_default_properties.sort.join(', ') + ', since it has more than one network configured'
      end

      def validate_only_one_default_network(default_networks_for_properties, instance_group_name)
        multiple_defaults = default_networks_for_properties.select do |_, networks|
          networks.count > 1
        end
        return if multiple_defaults.empty?

        message_for_each_property = multiple_defaults.map do |property, networks|
          quoted_network_names = networks.map { |network| "'#{network.name}'" }.join(', ')
          "'#{property}' has default networks: #{quoted_network_names}."
        end
        raise JobNetworkMultipleDefaults,
              "Instance group '#{instance_group_name}' specified more than one network to contain default. " +
              message_for_each_property.join(' ')
      end

      def default_networks_for_properties(networks)
        @valid_properties.inject({}) do |defaults, property|
          defaults.merge(property => networks.select { |network| network.default_for?(property) })
        end
      end
    end
  end
end
