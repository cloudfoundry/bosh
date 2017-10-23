module Bosh::Director
  class DnsEncoder
    def initialize(service_groups={}, az_hash={}, network_name_hash={}, instance_uuid_num_hash={}, short_dns_enabled=false)
      @az_hash = az_hash
      @service_groups = service_groups
      @short_dns_enabled = short_dns_enabled
      @network_name_hash = network_name_hash
      @instance_uuid_num_hash = instance_uuid_num_hash
    end

    def encode_query(criteria)
      octets = []

      if criteria[:uuid].nil? || @short_dns_enabled
        octets << "q-#{query_slug(criteria)}"
      else
        octets << criteria[:uuid]
      end

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

    def num_for_uuid(uuid)
      if uuid.nil?
        return nil
      end

      index = @instance_uuid_num_hash[uuid]
      raise RuntimeError.new("Unknown instance UUID: '#{uuid}'") if index.nil?
      "#{index}"
    end

    def id_for_network(network_name)
      if network_name.nil?
        return nil
      end
      index = @network_name_hash[network_name]
      raise RuntimeError.new("Unknown Network: '#{network_name}'") if index.nil?
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
      azs = criteria[:azs]
      aznums = []
      unless azs.nil?
        azs.each do |az|
          aznums << id_for_az(az)
        end
      end

      queries << aznums.map do |item|
        "a#{item}"
      end

      if @short_dns_enabled
        uuid = criteria[:uuid]
        unless uuid.nil?
          instance_num = num_for_uuid(uuid)
          queries << "m#{instance_num}"
        end

        network = criteria[:default_network]
        unless network.nil?
          network_id = id_for_network(network)
          queries << "n#{network_id}"
        end
      end

      queries << 's0' # healthy by default; also prevents empty queries
      queries.flatten.sort.join
    end

    def encode_long_subdomains(criteria)
      [
        Canonicalizer.canonicalize(criteria[:instance_group]),
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
