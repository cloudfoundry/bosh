require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe Network do
    let(:deployment_plan) { instance_double('Bosh::Director::DeploymentPlan::Planner') }

    describe :reserve! do
      let(:network) do
        BD::DeploymentPlan::DynamicNetwork.new(
          {
            "name" => "foo",
            "cloud_properties" => {
                "foz" => "baz"
            }
          },
          logger
        )
      end
      let(:instance) { instance_double(Instance, model: Bosh::Director::Models::Instance.make) }

      it 'delegates to #reserve' do
        reservation = BD::NetworkReservation.new_dynamic(instance)

        expect(network).to receive(:reserve) { reservation.reserved = true }

        network.reserve!(reservation, 'fake-origin')
      end

      it 'delegates to reservation#handle_error' do
        reservation = BD::NetworkReservation.new_dynamic(instance)

        expect(network).to receive(:reserve) { reservation.reserved = false }
        expect(reservation).to receive(:handle_error).with('fake-origin')

        network.reserve!(reservation, 'fake-origin')
      end
    end
  end
end
