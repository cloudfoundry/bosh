require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::InstanceNetworkReservations do
    let(:instance_network_reservations) { DeploymentPlan::InstanceNetworkReservations.new(instance, logger) }

    let(:instance) do
      instance_double(DeploymentPlan::Instance, to_s: 'fake-instance')
    end

    describe 'when adding reservation on the same network' do
      it 'throws nice error' do
        network = instance_double(DeploymentPlan::ManualNetwork, name: 'fake-network')

        reservation = StaticNetworkReservation.new(
          instance,
          network,
          '192.168.0.1'
        )
        instance_network_reservations.add(reservation)

        second_reservation = StaticNetworkReservation.new(
          instance,
          network,
          '192.168.0.2'
        )

        expect {
          instance_network_reservations.add(second_reservation)
        }.to raise_error NetworkReservationAlreadyExists,
          "Failed to add static reservation with IP '192.168.0.2' for instance 'fake-instance' on network 'fake-network', " +
            "instance already has static reservation with IP '192.168.0.1' on the same network"
      end
    end

    describe :add_existing do
      it 'reserves existing IPs' do
        vip_repo = DeploymentPlan::VipRepo.new(logger)
        ip_repo = DeploymentPlan::InMemoryIpRepo.new(logger)
        ip_provider = DeploymentPlan::IpProviderV2.new(ip_repo, vip_repo, false, logger)
        network_name = 'my-network'
        network = instance_double(DeploymentPlan::Network, name: network_name)
        deployment = instance_double(DeploymentPlan::Planner, ip_provider: ip_provider, network: network)

        instance_network_reservations.add_existing(deployment, network_name, '192.168.1.2', '')

        expect {
          instance_network_reservations.add_existing(deployment, network_name, '192.168.1.2', '')
        }.to raise_error BD::NetworkReservationAlreadyInUse
      end
    end
  end
end
