module Bosh::Director
  class DnsRecords

    attr_reader :version

    def initialize(version, include_index_records, az_hash, logger)
      @version = version
      @record_keys = ['id', 'instance_group', 'az', 'az_id', 'network', 'deployment', 'ip', 'domain', 'agent_id']
      @record_infos = []
      @records = []
      @include_index_records = include_index_records
      @az_hash = az_hash
      @logger = logger
    end

    def add_record(instance_id, index, instance_group_name, az_name, network_name, deployment_name, ip, domain, agent_id)
      add_hosts_record(instance_id, instance_group_name, network_name, deployment_name, ip, domain)
      if @include_index_records
        add_hosts_record(index, instance_group_name, network_name, deployment_name, ip, domain)
      end

      az_idx = "#{@az_hash[az_name] || ''}"
      @logger.debug("dns record contains AZ name with no corresponding id: '#{az_name}'") if az_idx == ''

      @record_infos << [
        instance_id,
        Canonicalizer.canonicalize(instance_group_name),
        az_name,
        az_idx,
        Canonicalizer.canonicalize(network_name),
        Canonicalizer.canonicalize(deployment_name),
        ip,
        domain,
        agent_id
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
