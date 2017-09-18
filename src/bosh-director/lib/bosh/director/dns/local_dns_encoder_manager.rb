module Bosh::Director
  class LocalDnsEncoderManager
    def self.persist_az_names(azs)
      azs.each do |azname|
        self.encode_az(azname)
      end
    end

    def self.create_dns_encoder(use_short_dns_names=false)
      az_hash = {}

      Models::LocalDnsEncodedAz.all.each do |item|
        az_hash[item.name] = item.id.to_s
      end

      service_groups = {}
      Bosh::Director::Models::LocalDnsServiceGroup.all_groups_eager_load.each do |item|
        service_groups[{
          instance_group: item.instance_group.name,
          deployment: item.instance_group.deployment.name,
          network: item.network.name
        }] = item.id.to_s
      end

      Bosh::Director::DnsEncoder.new(service_groups, az_hash, use_short_dns_names)
    end

    def self.new_encoder_with_updated_index(azs)
      self.persist_az_names(azs)
      self.create_dns_encoder
    end

    private

    def self.encode_az(name)
      Models::LocalDnsEncodedAz.create(name: name)
      rescue Sequel::UniqueConstraintViolation
    end
  end
end
