module Bosh::Director
  module DeploymentPlan
    class NullGlobalNetworkResolver
      def reserved_ranges
        []
      end
    end

    class GlobalNetworkResolver
      include Bosh::Director::ValidationHelper
      include IpUtil

      def initialize(current_deployment, director_ips, logger)
        @current_deployment = current_deployment
        @director_ips = director_ips || []
        @logger = logger
        @range_combiner = CidrRangeCombiner.new
      end

      def reserved_ranges
        return Set.new unless @current_deployment.using_global_networking?
        combined = reserved_legacy_ranges + director_reserved_ranges
        log_reserved_ranges(combined)
        combined
      end

      private

      def director_reserved_ranges
        Set.new(@director_ips.map { |ip| NetAddr::CIDR.create(ip) })
      end

      def reserved_legacy_ranges
        @cache ||= begin
          reserved_ranges = Set.new
          other_deployments = Models::Deployment.
            exclude(cloud_configs: Models::Config.where(type: 'cloud')).
            exclude(name: @current_deployment.name).
            exclude(manifest: nil).all

          other_deployments.each do |deployment|
            add_networks_from_deployment(deployment, reserved_ranges)
          end
          reserved_ranges
        end
      end

      def log_reserved_ranges(cidr_ranges)
        combined_range_tuples = @range_combiner.combine_ranges(cidr_ranges)
        output = format_range_output_from_tuples( combined_range_tuples )
        @logger.info("Following networks and individual IPs are reserved by non-cloud-config deployments: #{output}")
      end

      def format_range_output_from_tuples(string_ip_tuples)
        range_strings = string_ip_tuples.map do |r|
          first = r[0]
          last = r[1]
          first == last ? first : "#{first}-#{last}"
        end
        range_strings.join(', ')
      end

      def add_networks_from_deployment(deployment, ranges)
        networks = safe_property(YAML.load(deployment.manifest), 'networks', :class => Array, :default => [])
        networks.each do |network_spec|
          add_network(network_spec, ranges)
        end
      end

      def add_network(network_spec, ranges)
        type = safe_property(network_spec, 'type', :class => String, :default => 'manual')
        return unless type == 'manual'

        subnets = safe_property(network_spec, 'subnets', :class => Array)
        subnets.each do |subnet_spec|
          range_property = safe_property(subnet_spec, 'range', :class => String)
          range = NetAddr::CIDR.create(range_property)
          reserved_property = safe_property(subnet_spec, 'reserved', :optional => true)
          reserved_ranges = Set.new([range])
          each_ip(reserved_property) do |unused_ip|
            reserved_ranges = remove_deployment_owned_addresses(unused_ip, reserved_ranges)
          end
          ranges.merge(reserved_ranges)
        end
      end

      def remove_deployment_owned_addresses(reserved_property_entry, reserved_ranges)
        address_range = NetAddr::CIDRv4.new(reserved_property_entry)
        reserved_range_with_ip = reserved_ranges.find { |r| r.contains?(address_range) || r == address_range }
        reserved_ranges.delete(reserved_range_with_ip)
        if (!reserved_range_with_ip.nil?) && (reserved_range_with_ip != address_range)
          remainder = reserved_range_with_ip.remainder(address_range, Objectify: true)
          reserved_ranges.merge(Set.new(remainder))
        end
        reserved_ranges
      end
    end
  end
end
