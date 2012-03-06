# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlan
    class NetworkSpec
      include IpUtil
      include DnsHelper
      include ValidationHelper

      VALID_DEFAULT_NETWORK_PROPERTIES = Set.new(["dns", "gateway"])
      VALID_DEFAULT_NETWORK_PROPERTIES_ARRAY = VALID_DEFAULT_NETWORK_PROPERTIES.to_a.sort

      attr_accessor :deployment
      attr_accessor :name
      attr_accessor :canonical_name

      def initialize(deployment, network_spec)
        @deployment = deployment
        @name = safe_property(network_spec, "name", :class => String)
        @canonical_name = canonical(@name)
        @subnets = []
        safe_property(network_spec, "subnets", :class => Array).each do |subnet_spec|
          new_subnet = NetworkSubnetSpec.new(self, subnet_spec)
          @subnets.each do |subnet|
            raise "Overlapping subnets" if subnet.overlaps?(new_subnet)
          end
          @subnets << new_subnet
        end
      end

      def allocate_dynamic_ip
        ip = nil
        @subnets.each do |subnet|
          ip = subnet.allocate_dynamic_ip
          break if ip
        end
        unless ip
          raise Bosh::Director::NotEnoughCapacity, "not enough dynamic IPs"
        end
        ip
      end

      def reserve_ip(ip)
        ip = ip_to_i(ip)

        reserved = nil
        @subnets.each do |subnet|
          if subnet.range.contains?(ip)
            reserved = subnet.reserve_ip(ip)
            break
          end
        end
        reserved
      end

      def network_settings(ip, default_properties)
        config = nil
        ip = ip_to_netaddr(ip)
        @subnets.each do |subnet|
          if subnet.range.contains?(ip)
            config = {
                "ip" => ip.ip,
                "netmask" => subnet.netmask,
                "cloud_properties" => subnet.cloud_properties
            }

            if default_properties
              config["default"] = default_properties.sort
            end

            config["dns"] = subnet.dns if subnet.dns
            config["gateway"] = subnet.gateway.ip if subnet.gateway
            break
          end
        end
        config
      end

      def release_ip(ip)
        ip = ip_to_netaddr(ip)
        @subnets.each do |subnet|
          if subnet.range.contains?(ip)
            subnet.release_ip(ip)
            break
          end
        end
      end
    end
  end
end