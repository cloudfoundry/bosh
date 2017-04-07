module Bosh::Director
  class DnsRecords

    attr_reader :version

    def initialize(version, include_index_records)
      @version = version
      @record_keys = ['id', 'instance_group', 'az', 'network', 'deployment', 'ip']
      @record_infos = []
      @records = []
      @include_index_records = include_index_records
    end

    def add_record(instance_id, index, instance_group_name, az_name, network_name, deployment_name, ip)
      add_hosts_record(instance_id, instance_group_name, network_name, deployment_name, ip)
      if @include_index_records
        add_hosts_record(index, instance_group_name, network_name, deployment_name, ip)
      end

      @record_infos << [instance_id, instance_group_name, az_name, network_name, deployment_name, ip]
    end

    def shasum
      ::Digest::SHA1.hexdigest(to_json)
    end

    def to_json
      JSON.dump({records: @records, version: @version, record_keys: @record_keys, record_infos: @record_infos})
    end

    private

    def add_hosts_record(hostname, instance_group_name, network_name, deployment_name, ip)
      record_name = DnsNameGenerator.dns_record_name(
          hostname,
          instance_group_name,
          network_name,
          deployment_name,
      )
      @records << [ip, record_name]
    end
  end
end
