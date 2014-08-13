require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe Network do
    let(:deployment_plan) { instance_double('Bosh::Director::DeploymentPlan::Planner') }

    describe :reserve! do
      let(:network) do
        BD::DeploymentPlan::DynamicNetwork.new(
          deployment_plan,
          {
            "name" => "foo",
            "cloud_properties" => {
                "foz" => "baz"
            }
          }
        )
      end

      it 'delegates to #reserve' do
        reservation = BD::NetworkReservation.new(
          :ip => "0.0.0.1",
          :type => BD::NetworkReservation::DYNAMIC
        )

        expect(network).to receive(:reserve) { reservation.reserved = true }

        network.reserve!(reservation, 'fake-origin')
      end

      it 'delegates to reservation#handle_error' do
        reservation = BD::NetworkReservation.new(
          :ip => "0.0.0.1",
          :type => BD::NetworkReservation::DYNAMIC
        )

        expect(network).to receive(:reserve) { reservation.reserved = false }
        expect(reservation).to receive(:handle_error).with('fake-origin')

        network.reserve!(reservation, 'fake-origin')
      end
    end
  end
end
