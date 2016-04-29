module Bosh::Director
  module DeploymentPlan
    class NullGlobalNetworkResolver
      def reserved_legacy_ranges
        []
      end
    end

    class GlobalNetworkResolver
      include Bosh::Director::ValidationHelper
      include IpUtil

      def initialize(current_deployment, logger)
        @logger = logger
        @current_deployment = current_deployment
      end

      def reserved_legacy_ranges
        return Set.new unless @current_deployment.using_global_networking?

        reserved_addresses = Set.new
        legacy_ranges.each{|k,v| reserved_addresses += v }
        reserved_addresses
      end

      private

      def legacy_ranges
        @reserved_legacy_ranges ||= begin
          reserved_ranges = {}

          other_deployments = Models::Deployment.where(cloud_config_id: nil).
            exclude(name: @current_deployment.name).
            exclude(manifest: nil).all

          other_deployments.each do |deployment|
            add_networks_from_deployment(deployment, reserved_ranges)
          end
          log_reserved_ranges(reserved_ranges)
          reserved_ranges
        end
      end

      def log_reserved_ranges(reserved_ranges)
        ip_range_sets = reserved_ranges
                          .map {|r| r[1] }
                          .inject {|total_set, network_set| total_set + network_set } || []
        single_ips = []
        ranges = []
        ip_range_sets.each do |r|
          if r.netmask == '/32'
            single_ips << r.ip
          else
            ranges << r
          end
        end

        @logger.info("Following networks and individual IPs are reserved by non-cloud-config deployments: Networks: #{ranges.join(', ')}; IPs: #{single_ips.join(', ')}")
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
