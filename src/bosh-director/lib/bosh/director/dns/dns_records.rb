module Bosh::Director
  class DnsRecords

    attr_reader :version

    def initialize(version = 0)
      @version = version
      @record_keys = ['id', 'instance_group', 'az', 'network', 'deployment', 'ip']
      @record_infos = []
      @records = []
    end

    def add_record(instance_id, instance_group_name, az_name, network_name, deployment_name, ip, fqdn)
      @records << [ip, fqdn]
      @record_infos << [instance_id, instance_group_name, az_name, network_name, deployment_name, ip]
    end

    def shasum
      ::Digest::SHA1.hexdigest(to_json)
    end

    def to_json
      JSON.dump({records: @records, version: @version, record_keys: @record_keys, record_infos: @record_infos})
    end
  end
end
