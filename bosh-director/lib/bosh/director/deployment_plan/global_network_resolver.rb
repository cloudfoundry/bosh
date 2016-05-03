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

        reserved_ranges = get_all_ranges(reserved_ranges)

        reserved_ranges = sort_ranges(reserved_ranges)

        reserved_ranges = min_max_tuples(reserved_ranges)

        reserved_ranges = combine_ranges(reserved_ranges)

        output = format_range_output(reserved_ranges)

        @logger.info("Following networks and individual IPs are reserved by non-cloud-config deployments: #{output}")
      end

      def format_range_output(reserved_ranges)
        reserved_ranges.map {|r| r.first == r.last ? "#{r.first.ip}" : "#{r.first.ip}-#{r.last.ip}" }.join(', ')
      end

      def get_all_ranges(reserved_ranges)
        reserved_ranges.values.map(&:to_a).flatten
      end

      def sort_ranges(reserved_ranges)
        reserved_ranges.sort do|e1,e2|
          e1.to_i <=> e2.to_i
        end
      end

      def min_max_tuples(reserved_ranges)
        reserved_ranges.map do |r|
          [r.first(Objectify: true), r.last(Objectify: true)]
        end
      end

      def combine_ranges(reserved_ranges)
        i=0
        combined_ranges = []

        while i<reserved_ranges.length
          temp = reserved_ranges[i]
          can_combine = true
          while can_combine
            if !reserved_ranges[i+1].nil? && temp[1].succ == reserved_ranges[i+1][0]
              temp[1] = reserved_ranges[i+1][1]
              i+=1
            else
              can_combine = false
            end
          end
          combined_ranges << temp
          i+=1
        end
        combined_ranges
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
