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

    def self.create_dns_encoder(use_short_dns_names = false)
      az_hash = Models::LocalDnsEncodedAz.as_hash(:name, :id)

      service_groups = {}
      Bosh::Director::Models::LocalDnsEncodedInstanceGroup.
        inner_join(:deployments, Sequel.qualify('local_dns_encoded_instance_groups', 'deployment_id') => Sequel.qualify('deployments', 'id')).
        select(
          Sequel.expr(Sequel.qualify('local_dns_encoded_instance_groups', 'id')).as(:id),
          Sequel.expr(Sequel.qualify('local_dns_encoded_instance_groups', 'name')).as(:name),
          Sequel.expr(Sequel.qualify('deployments', 'name')).as(:deployment_name),
        ).all.each do |join_row|
        service_groups[{
          instance_group: join_row[:name],
          deployment: join_row[:deployment_name],
        }] = join_row[:id].to_s
      end

      Bosh::Director::DnsEncoder.new(service_groups, az_hash, use_short_dns_names)
    end

    def self.new_encoder_with_updated_index(plan)
      persist_az_names(plan.availability_zones.map(&:name))
      persist_network_names(plan.networks.map(&:name))
      persist_service_groups(plan)
      create_dns_encoder(plan.use_short_dns_addresses?)
    end

    private

    def self.with_skip_dupes
      yield
    rescue Sequel::UniqueConstraintViolation => _
    end

    def self.encode_az(name)
      with_skip_dupes { Models::LocalDnsEncodedAz.find_or_create(name: name) }
    end

    def self.encode_instance_group(name, deployment_model)
      with_skip_dupes do
        Models::LocalDnsEncodedInstanceGroup.find_or_create(
          name: name,
          deployment: deployment_model,
        )
      end
    end

    def self.encode_network(name)
      with_skip_dupes { Models::LocalDnsEncodedNetwork.find_or_create(name: name) }
    end

    def self.persist_service_groups(plan)
      deployment_model = plan.model

      plan.instance_groups.each do |ig|
        encode_instance_group(ig.name, deployment_model)
      end
    end
  end
end
