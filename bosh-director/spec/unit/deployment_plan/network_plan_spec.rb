require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe NetworkPlanner do
    describe :plan_ips do
      let(:network_planner) { NetworkPlanner.new(logger) }
      let(:instance) { instance_double(Instance, desired_network_reservations: nil) }
      let(:network) { instance_double(ManualNetwork, name: 'my-network') }
      let(:existing_reservations) {
        [
          BD::ExistingNetworkReservation.new(instance, network, '192.168.1.2'),
          BD::ExistingNetworkReservation.new(instance, network, '192.168.1.3')
        ]
      }

      before { existing_reservations.each { |reservation| reservation.mark_reserved } }

      context 'when desired reservations are the same as existing ones' do
        let(:dynamic_network_reservation) { BD::DesiredNetworkReservation.new_dynamic(instance, network) }
        let(:static_network_reservation) { BD::DesiredNetworkReservation.new_static(instance, network, '192.168.1.2') }
        let(:desired_reservations) {
          [
            static_network_reservation,
            dynamic_network_reservation
          ]
        }

        before do
          existing_reservations[0].resolve_type(:static)
          existing_reservations[1].resolve_type(:dynamic)
        end

        it 'should keep existing reservation and return no desired new or obsolete network plans' do
          network_plans = network_planner.plan_ips(desired_reservations, existing_reservations)
          obsolete_plans = network_plans.select(&:obsolete?)
          desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

          expect(desired_plans.count).to eq(1)
          expect(obsolete_plans.count).to eq(1)
        end

        it 'should update instance#desired_network_reservations with desired reservations' do
          network_planner.plan_ips(desired_reservations, existing_reservations)
          allow(instance).to receive(:desired_network_reservations).and_return(desired_reservations)

          reservations = instance.desired_network_reservations

          expect(reservations.count).to eq(2)
        end
      end

      context 'when there new reservations' do
        let(:dynamic_network_reservation) { BD::DesiredNetworkReservation.new_dynamic(instance, network) }
        let(:desired_reservations) {
          [
            BD::DesiredNetworkReservation.new_static(instance, network, '192.168.1.2'),
            BD::DesiredNetworkReservation.new_static(instance, network, '192.168.1.4'),
            dynamic_network_reservation
          ]
        }

        before do
          existing_reservations[0].resolve_type(:static)
          existing_reservations[1].resolve_type(:dynamic)
        end

        it 'should return desired network plans for the new reservations' do
          network_plans = network_planner.plan_ips(desired_reservations, existing_reservations)
          obsolete_plans = network_plans.select(&:obsolete?)
          desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

          expect(desired_plans.count).to eq(2)
          expect(obsolete_plans.count).to eq(1)
        end
      end

      context 'when there is no desired reservations' do
        let(:dynamic_network_reservation) { BD::DesiredNetworkReservation.new_dynamic(instance, network) }
        let(:desired_reservations) { [] }

        before do
          existing_reservations[0].resolve_type(:static)
          existing_reservations[1].resolve_type(:dynamic)
        end

        it 'should return desired network plans for the new reservations' do
          network_plans = network_planner.plan_ips(desired_reservations, existing_reservations)
          existing_plans = network_plans.select(&:existing?)
          obsolete_plans = network_plans.select(&:obsolete?)
          desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

          expect(existing_plans.count).to eq(0)
          expect(desired_plans.count).to eq(0)
          expect(obsolete_plans.count).to eq(2)
        end

        it 'should update instance#desired_network_reservations with desired reservations' do
          network_planner.plan_ips(desired_reservations, existing_reservations)
          allow(instance).to receive(:desired_network_reservations).and_return(desired_reservations)

          reservations = instance.desired_network_reservations

          expect(reservations).to be_empty
        end
      end
    end
  end
end
