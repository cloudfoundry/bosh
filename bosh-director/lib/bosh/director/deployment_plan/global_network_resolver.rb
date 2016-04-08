module Bosh::Director
  module DeploymentPlan
    class NullGlobalNetworkResolver
      def reserved_legacy_ranges(something)
        []
      end
    end

    class GlobalNetworkResolver
      include Bosh::Director::ValidationHelper
      include IpUtil

      def initialize(current_deployment)
        @current_deployment = current_deployment
      end

      def reserved_legacy_ranges(network_name)
        return Set.new unless @current_deployment.using_global_networking?
        legacy_ranges.fetch(network_name, Set.new)
      end

      private

      def legacy_ranges
        @reserved_legacy_ranges ||= begin
          reserved_legacy_ranges = {}

          other_deployments = Models::Deployment.where(cloud_config_id: nil).
            exclude(name: @current_deployment.name).
            exclude(manifest: nil).all

          other_deployments.each do |deployment|
            add_networks_from_deployment(deployment, reserved_legacy_ranges)
          end

          reserved_legacy_ranges
        end
      end

      def add_networks_from_deployment(deployment, ranges)
        networks = safe_property(Psych.load(deployment.manifest), 'networks', :class => Array, :default => [])
        networks.each do |network_spec|
          add_network(network_spec, ranges)
        end
      end

      def add_network(network_spec, ranges)
        name = safe_property(network_spec, 'name', :class => String)
        ranges[name] ||= Set.new

        type = safe_property(network_spec, 'type', :class => String, :default => 'manual')
        return unless type == 'manual'

        subnets = safe_property(network_spec, 'subnets', :class => Array)
        subnets.each do |subnet_spec|
          range_property = safe_property(subnet_spec, 'range', :class => String)
          range = NetAddr::CIDR.create(range_property)
          reserved_property = safe_property(subnet_spec, 'reserved', :optional => true)

          reserved_ranges = Set.new([range])

          each_ip(reserved_property) do |ip|
            addr = NetAddr::CIDRv4.new(ip)
            range_with_ip = reserved_ranges.find { |r| r.contains?(addr) || r == addr }
            reserved_ranges.delete(range_with_ip)
            if range_with_ip != addr
              remainder = range_with_ip.remainder(addr, Objectify: true)
              reserved_ranges += Set.new(remainder)
            end
          end

          ranges[name] += reserved_ranges
        end
      end
    end
  end
end
