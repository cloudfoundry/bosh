module Bosh::Director
  class DnsEncoder
    def initialize(service_groups = {}, az_hash = {}, short_dns_enabled = false, link_dns_enabled = false)
      @az_hash = az_hash
      @service_groups = service_groups
      @short_dns_enabled = short_dns_enabled
      @link_dns_enabled = link_dns_enabled
    end

    def encode_link(link_def, criteria = {})
      force_short_dns = nil
      criteria = criteria.clone

      criteria[:deployment_name] = link_def.provider_deployment_name

      if @link_dns_enabled
        criteria[:group_type] = Models::LocalDnsEncodedGroup::Types::LINK
        criteria[:group_name] = link_def.provider_name + '-' + link_def.provider_type
        force_short_dns = true
      else
        criteria[:group_type] = Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP
        criteria[:group_name] = link_def.source_instance_group.name
      end

      encode_query(criteria, force_short_dns)
    end

    def encode_query(criteria, force_short_dns = nil)
      octets = []

      use_short_dns = !force_short_dns.nil? ? force_short_dns : @short_dns_enabled
      octets << if criteria[:uuid].nil? || use_short_dns
                  "q-#{query_slug(criteria, use_short_dns)}"
                else
                  criteria[:uuid]
                end

      if use_short_dns
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

      index = Models::Instance.where(uuid: uuid).get(:id)
      raise RuntimeError.new("Unknown instance UUID: '#{uuid}'") if index.nil?
      "#{index}"
    end

    def id_for_network(network_name)
      if network_name.nil?
        return nil
      end
      index = Models::LocalDnsEncodedNetwork.where(name: network_name).get(:id)
      raise RuntimeError.new("Unknown Network: '#{network_name}'") if index.nil?
      "#{index}"
    end

    def id_for_group_tuple(group_type, group_name, deployment)
      index = @service_groups[{
        group_type: group_type,
        group_name: group_name,
        deployment: deployment,
      }]
      index.to_s
    end

    private

    def query_slug(criteria, use_short_dns)
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

      if use_short_dns
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

      healthiness = {
        'healthy' => 3,
        'unhealthy' => 1,
        'all' => 4,
        'default' => 0
      }
      queries << "s#{healthiness.fetch(criteria[:status], 0)}"
      queries.flatten.sort.join
    end

    def encode_long_subdomains(criteria)
      [
        Canonicalizer.canonicalize(criteria.fetch(:group_name)),
        Canonicalizer.canonicalize(criteria.fetch(:default_network)),
        Canonicalizer.canonicalize(criteria.fetch(:deployment_name)),
      ]
    end

    def encode_service_group(criteria)
      number = id_for_group_tuple(
        criteria[:group_type],
        criteria[:group_name],
        criteria[:deployment_name]
      )
      "q-g#{number}"
    end
  end
end
