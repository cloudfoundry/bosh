module Bosh::Director
  class LocalDnsEncoderManager
    def self.persist_az_names(azs)
      azs.each do |azname|
        self.encode_az(azname)
      end
    end

    def self.persist_network_names(networks)
      networks.each do |networkname|
        self.encode_network(networkname)
      end
    end

    def self.create_dns_encoder(use_short_dns_names)
      az_hash = {}
      network_name_hash = {}

      Models::LocalDnsEncodedAz.all.each do |item|
        az_hash[item.name] = item.id.to_s
      end

      Models::LocalDnsEncodedNetwork.all.each do |item|
        network_name_hash[item.name] = item.id.to_s
      end

      service_groups = {}
      Bosh::Director::Models::LocalDnsEncodedInstanceGroup.eager(:deployment).each do |ig|
        service_groups[{
          instance_group: ig.name,
          deployment: ig.deployment.name,
        }] = ig.id.to_s
      end

      instance_uuids = {}
      Bosh::Director::Models::Instance.each do |i|
        instance_uuids[i.uuid] = i.id
      end

      Bosh::Director::DnsEncoder.new(service_groups, az_hash, network_name_hash, instance_uuids, use_short_dns_names)
    end

    def self.new_encoder_with_updated_index(plan)
      persist_az_names(plan.availability_zones.map(&:name))
      persist_network_names(plan.networks.map(&:name))
      persist_service_groups(plan)
      create_dns_encoder(plan.use_short_dns_addresses?)
    end

    private

    def self.encode_az(name)
      Models::LocalDnsEncodedAz.find_or_create(name: name)
    end

    def self.encode_instance_group(name, deployment_model)
      Models::LocalDnsEncodedInstanceGroup.find_or_create(
        name: name,
        deployment: deployment_model)
    end

    def self.encode_network(name)
      Models::LocalDnsEncodedNetwork.find_or_create(name: name)
    end

    def self.persist_service_groups(plan)
      deployment_model = plan.model

      plan.instance_groups.each do |ig|
        encode_instance_group(ig.name, deployment_model)
      end
    end
  end
end
