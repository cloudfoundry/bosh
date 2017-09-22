module Bosh::Director
  class DnsEncoder
    def initialize(service_groups={}, az_hash={}, short_dns_enabled=false)
      @az_hash = az_hash
      @service_groups = service_groups
      @short_dns_enabled = short_dns_enabled
    end

    def encode_query(criteria)
      octets = []

      octets << "q-#{query_slug(criteria)}"

      if @short_dns_enabled
        octets << encode_service_group(criteria)
      else
        octets += encode_long_subdomains(criteria)
      end

      octets << criteria[:root_domain]
      octets.join('.')
    end

    def id_for_az(az_name)
      if az_name.nil?
        return nil
      end

      index = @az_hash[az_name]
      raise RuntimeError.new("Unknown AZ: '#{az_name}'") if index.nil?
      "#{index}"
    end

    def id_for_group_tuple(instance_group, deployment)
      index = @service_groups[{
        instance_group: instance_group,
        deployment: deployment
      }]
      "#{index}"
    end

    private

    def query_slug(criteria)
      queries = []
      # these should be parsed in alphabetical order for the resulting encoded query.

      # present the AZs in index-sorted order
      azs = criteria[:azs]
      aznums = []
      unless azs.nil?
        azs.each do |az|
          aznums << id_for_az(az)
        end
      end

      queries << aznums.sort.map do |item|
        "a#{item}"
      end

      queries << 's0' # healthy by default; also prevents empty queries
      queries.join
    end

    def encode_long_subdomains(criteria)
      [ Canonicalizer.canonicalize(criteria[:instance_group]),
        Canonicalizer.canonicalize(criteria[:default_network]),
        Canonicalizer.canonicalize(criteria[:deployment_name])
      ]
    end

    def encode_service_group(criteria)
      "g-#{id_for_group_tuple(
        criteria[:instance_group],
        criteria[:deployment_name])}"
    end
  end
end
