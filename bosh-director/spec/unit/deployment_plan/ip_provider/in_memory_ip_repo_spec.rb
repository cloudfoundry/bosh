require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe InMemoryIpProvider do
    let(:ip_repo) { InMemoryIpRepo.new(logger) }

    let(:ip_address) { NetAddr::CIDR.create('192.168.1.5') }
    let(:subnet) { ManualNetworkSubnet.new(network, network_spec['subnets'].first, availability_zones, [], ip_provider_factory) }
    let(:network) do
      BD::DeploymentPlan::ManualNetwork.new(
        network_spec,
        availability_zones,
        global_network_resolver,
        ip_provider_factory,
        logger
      )
    end
    let(:availability_zones) do
      [
        BD::DeploymentPlan::AvailabilityZone.new('zone_1', {}),
        BD::DeploymentPlan::AvailabilityZone.new('zone_2', {})
      ]
    end

    let(:network_spec) { cloud_manifest['networks'].first }
    let(:global_network_resolver) { BD::DeploymentPlan::GlobalNetworkResolver.new(deployment_plan) }
    let(:deployment_manifest) { Bosh::Spec::Deployments.simple_manifest }
    let(:cloud_manifest) { Bosh::Spec::Deployments.simple_cloud_config }
    let(:cloud_config) { BD::Models::CloudConfig.make(manifest: cloud_manifest) }
    let(:deployment_plan) { planner_factory.create_from_manifest(deployment_manifest, cloud_config, {}) }
    let(:planner_factory) { BD::DeploymentPlan::PlannerFactory.create(BD::Config.event_log, BD::Config.logger) }
    let(:ip_provider_factory) { BD::DeploymentPlan::IpProviderFactory.new(logger, {}) }
    let(:network_name) { network_spec['name'] }
    let(:instance) { instance_double(BD::DeploymentPlan::Instance, availability_zone: nil) }

    describe :add do
      context 'when IP was already added in that subnet' do
        before do
          ip_repo.add(ip_address, subnet)
        end

        it 'raises an error' do
          message = "Failed to reserve IP '192.168.1.5' for '#{network_name}': already reserved"
          expect {
            ip_repo.add(ip_address, subnet)
          }.to raise_error(BD::NetworkReservationAlreadyInUse, message)
        end
      end

      context 'when IP is outside of subnet range' do
        let(:ip_address) { NetAddr::CIDR.create('192.168.5.5') }
        it 'raises an error' do
          message = "Can't reserve IP '192.168.5.5' to '#{network_name}' network: " +
            "it's neither in dynamic nor in static pool"
          expect {
            ip_repo.add(ip_address, subnet)
          }.to raise_error(Bosh::Director::NetworkReservationIpNotOwned,
              message)
        end
      end

      it 'adds the IP' do
        ip_repo.add(ip_address, subnet)

        expect {
          ip_repo.add(ip_address, subnet)
        }.to raise_error BD::NetworkReservationAlreadyInUse
      end
    end

    describe :delete do
      it 'should delete IPs' do
        ip_repo.add(ip_address, subnet)

        expect {
          ip_repo.add(ip_address, subnet)
        }.to raise_error BD::NetworkReservationAlreadyInUse

        ip_repo.delete(ip_address, subnet)

        expect {
          ip_repo.add(ip_address, subnet)
        }.to_not raise_error
      end

      context 'when IP is outside of subnet range' do
        let(:ip_address) { NetAddr::CIDR.create('192.168.5.5') }

        it 'should fail if the IP is not in range' do
          message = "Can't release IP '192.168.5.5' back to '#{network_name}' network: " +
            "it's neither in dynamic nor in static pool"
          expect {
            ip_repo.delete(ip_address, subnet)
          }.to raise_error(Bosh::Director::NetworkReservationIpNotOwned,
              message)
        end
      end
    end

    context 'when IP is a Fixnum' do
      let(:ip_address_to_i) { NetAddr::CIDR.create('192.168.1.3').to_i }
      it 'adds and deletes IPs' do
        ip_repo.add(ip_address_to_i, subnet)

        expect {
          ip_repo.add(ip_address_to_i, subnet)
        }.to raise_error BD::NetworkReservationAlreadyInUse

        ip_repo.delete(ip_address_to_i, subnet)

        expect {
          ip_repo.add(ip_address_to_i, subnet)
        }.to_not raise_error
      end
    end
  end
end
