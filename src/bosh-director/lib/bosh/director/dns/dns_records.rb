module Bosh::Director
  class DnsRecords

    attr_reader :version

    def initialize(version, include_index_records, dns_query_encoder)
      @version = version
      @record_keys = ['id', 'instance_group', 'group_ids', 'az', 'az_id', 'network', 'deployment', 'ip', 'domain', 'agent_id', 'instance_index']
      @record_infos = []
      @records = []
      @include_index_records = include_index_records
      @dns_query_encoder = dns_query_encoder
    end

    def add_record(instance_id, index, instance_group_name, az_name, network_name, deployment_name, ip, domain, agent_id)
      add_hosts_record(instance_id, instance_group_name, network_name, deployment_name, ip, domain)
      if @include_index_records
        add_hosts_record(index, instance_group_name, network_name, deployment_name, ip, domain)
      end

      @record_infos << [
        instance_id,
        Canonicalizer.canonicalize(instance_group_name),
        [@dns_query_encoder.id_for_group_tuple(instance_group_name, deployment_name)],
        az_name,
        @dns_query_encoder.id_for_az(az_name),
        Canonicalizer.canonicalize(network_name),
        Canonicalizer.canonicalize(deployment_name),
        ip,
        domain,
        agent_id,
        index,
      ]
    end

    def shasum
      ::Digest::SHA1.hexdigest(to_json)
    end

    def to_json
      JSON.dump({records: @records, version: @version, record_keys: @record_keys, record_infos: @record_infos})
    end

    private

    def add_hosts_record(hostname, instance_group_name, network_name, deployment_name, ip, domain)
      record_name = DnsNameGenerator.dns_record_name(
        hostname,
        instance_group_name,
        network_name,
        deployment_name,
        domain
      )
      @records << [ip, record_name]
    end
  end
end
