require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe NetworkPlanner::ReservationReconciler do
    include Bosh::Director::IpUtil
    describe :reconcile do
      let(:network_planner) { NetworkPlanner::ReservationReconciler.new(logger) }
      let(:instance) { instance_double(Instance) }
      let(:network) { ManualNetwork.new('my-network', [], logger) }
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
          network_plans = network_planner.reconcile(desired_reservations, existing_reservations)
          obsolete_plans = network_plans.select(&:obsolete?)
          existing_plans = network_plans.select(&:existing?)
          desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

          expect(desired_plans.count).to eq(0)
          expect(existing_plans.count).to eq(2)
          expect(obsolete_plans.count).to eq(0)
        end

        context 'when the order of IPs changed' do
          let(:static_network_reservation1) { BD::DesiredNetworkReservation.new_static(instance, network, '192.168.1.3') }
          let(:static_network_reservation2) { BD::DesiredNetworkReservation.new_static(instance, network, '192.168.1.4') }
          let(:desired_reservations) {
            [
              static_network_reservation2,
              static_network_reservation1
            ]
          }

          before do
            existing_reservations[0].resolve_type(:static)
            existing_reservations[1].resolve_type(:static)
          end

          it 'should keep existing reservation that match IP address' do
            network_plans = network_planner.reconcile(desired_reservations, existing_reservations)
            obsolete_plans = network_plans.select(&:obsolete?)
            existing_plans = network_plans.select(&:existing?)
            desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

            expect(obsolete_plans.count).to eq(1)
            expect(ip_to_netaddr(obsolete_plans.first.reservation.ip)).to eq('192.168.1.2')
            expect(existing_plans.count).to eq(1)
            expect(ip_to_netaddr(existing_plans.first.reservation.ip)).to eq('192.168.1.3')
            expect(desired_plans.count).to eq(1)
            expect(ip_to_netaddr(desired_plans.first.reservation.ip)).to eq('192.168.1.4')
          end
        end
      end

      context 'when there are new reservations' do
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
          network_plans = network_planner.reconcile(desired_reservations, existing_reservations)
          obsolete_plans = network_plans.select(&:obsolete?)
          existing_plans = network_plans.select(&:existing?)
          desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

          expect(desired_plans.count).to eq(1)
          expect(existing_plans.count).to eq(2)
          expect(obsolete_plans.count).to eq(0)
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
          network_plans = network_planner.reconcile(desired_reservations, existing_reservations)
          existing_plans = network_plans.select(&:existing?)
          obsolete_plans = network_plans.select(&:obsolete?)
          desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

          expect(existing_plans.count).to eq(0)
          expect(desired_plans.count).to eq(0)
          expect(obsolete_plans.count).to eq(2)
        end
      end
    end
  end
end
