module Bosh::Director
  class DnsRecords
    attr_accessor :version

    def initialize(version, include_index_records, dns_query_encoder)
      @version = version
      @record_keys = %w[
        id num_id instance_group group_ids az az_id network
        network_id deployment ip domain agent_id instance_index
      ]
      @record_infos = []
      @records = []
      @aliases = {}
      @include_index_records = include_index_records
      @dns_query_encoder = dns_query_encoder
    end

    def add_record(record_hash)
      add_hosts_records(record_hash)

      links_group_ids = record_hash[:links]&.map do |link|
        encoded_id_for_link(link.symbolize_keys[:name], record_hash[:deployment_name])
      end

      @record_infos << [
        record_hash[:instance_id],
        record_hash[:num_id].to_s,
        Canonicalizer.canonicalize(record_hash[:instance_group_name]),
        [
          encoded_id_for_instance_group(record_hash[:instance_group_name], record_hash[:deployment_name]),
          *links_group_ids,
        ],
        record_hash[:az_name],
        @dns_query_encoder.id_for_az(record_hash[:az_name]),
        Canonicalizer.canonicalize(record_hash[:network_name]),
        @dns_query_encoder.id_for_network(record_hash[:network_name]),
        Canonicalizer.canonicalize(record_hash[:deployment_name]),
        record_hash[:ip],
        record_hash[:domain],
        record_hash[:agent_id],
        record_hash[:index],
      ]
    end

    def add_alias(source, target)
      @aliases[source] ||= []
      @aliases[source] << target
    end

    def shasum
      "sha256:#{::Digest::SHA256.hexdigest(to_json)}"
    end

    def to_json(*_args)
      JSON.dump(
        records: @records,
        version: @version,
        record_keys: @record_keys,
        record_infos: @record_infos,
        aliases: @aliases,
      )
    end

    private

    def encoded_id_for_link(link_name, deployment_name)
      @dns_query_encoder.id_for_group_tuple(
        Models::LocalDnsEncodedGroup::Types::LINK,
        link_name,
        deployment_name,
      )
    end

    def encoded_id_for_instance_group(instance_group_name, deployment_name)
      @dns_query_encoder.id_for_group_tuple(
        Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP,
        instance_group_name,
        deployment_name,
      )
    end

    def add_hosts_records(record_hash)
      args = [
        record_hash[:instance_group_name],
        record_hash[:network_name],
        record_hash[:deployment_name],
        record_hash[:domain],
      ]

      @records << [record_hash[:ip], DnsNameGenerator.dns_record_name(record_hash[:instance_id], *args)]

      return unless @include_index_records

      @records << [record_hash[:ip], DnsNameGenerator.dns_record_name(record_hash[:index], *args)]
    end
  end
end
