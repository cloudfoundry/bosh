# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module DnsHelper
    # TODO: rename to reflect DNS-related purpose
    def canonical(string)
      # a-z, 0-9, -, case insensitive, and must start with a letter
      string = string.downcase.gsub(/_/, "-").gsub(/[^a-z0-9-]/, "")
      if string =~ /^(\d|-)/
        raise DnsInvalidCanonicalName,
              "Invalid DNS canonical name `#{string}', must begin with a letter"
      end
      if string =~ /-$/
        raise DnsInvalidCanonicalName,
              "Invalid DNS canonical name `#{string}', can't end with a hyphen"
      end
      string
    end

    def dns_servers(network, spec)
      servers = nil
      dns_property = safe_property(spec, "dns",
                                   :class => Array, :optional => true)
      if dns_property
        servers = []
        dns_property.each do |dns|
          dns = NetAddr::CIDR.create(dns)
          unless dns.size == 1
            invalid_dns(network, "must be a single IP")
          end

          servers << dns.ip
        end
      end

      servers
    end

    # @param [String] network name
    # @param [String] reason
    # @raise NetworkInvalidDns
    def invalid_dns(network, reason)
      raise NetworkInvalidDns,
            "Invalid DNS for network `#{network}': #{reason}"
    end
  end
end