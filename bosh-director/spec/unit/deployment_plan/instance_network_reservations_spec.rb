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
  end
end
