module Bosh::Director
  class LocalDnsEncoderManager
    def self.persist_az_names(azs)
      azs.each do |azname|
        self.encode_az(azname)
      end
    end

    def self.create_dns_encoder
      az_hash = {}

      Models::LocalDnsEncodedAz.all.each do |item|
        az_hash[item.name] = item.id.to_s
      end

      Bosh::Director::DnsEncoder.new(az_hash)
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
