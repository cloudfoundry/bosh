require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe NetworkPlanner::ReservationReconciler do
    include Bosh::Director::IpUtil

    describe :reconcile do
      let(:network_planner) { NetworkPlanner::ReservationReconciler.new(instance_plan, per_spec_logger) }
      let(:instance_model) { FactoryBot.create(:models_instance, availability_zone: initial_az) }
      let(:instance) { instance_double(Instance, model: instance_model) }
      let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }
      let(:network) { ManualNetwork.new('my-network', subnets, '32', per_spec_logger) }
      let(:subnets) do
        [
          ManualNetworkSubnet.new(
            'my-network',
            IPAddr.new('192.168.1.0/24'),
            nil, nil, nil, nil, ['zone_1'], [],
            ['192.168.1.10'], nil, nil, '32'
          ),
          ManualNetworkSubnet.new(
            'my-network',
            IPAddr.new('192.168.2.0/24'),
            nil, nil, nil, nil, ['zone_2'], [],
            ['192.168.2.10'], nil, nil, '32'
          ),
        ]
      end
      let(:instance_plan) do
        network_plans = desired_reservations.map { |r| NetworkPlanner::Plan.new(reservation: r) }
        InstancePlan.new(
          desired_instance: DesiredInstance.new(nil, nil, desired_az),
          network_plans: network_plans,
          existing_instance: nil,
          instance: instance,
          variables_interpolator: variables_interpolator,
        )
      end
      let(:initial_az) { nil }
      let(:desired_az) { AvailabilityZone.new('zone_1', {}) }
      let(:existing_reservations) do
        [
          Bosh::Director::ExistingNetworkReservation.new(instance_model, network, '192.168.1.2/32', 'manual'),
          Bosh::Director::ExistingNetworkReservation.new(instance_model, network, '192.168.1.3/32', 'manual'),
        ]
      end

      let(:dynamic_network_reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network) }
      let(:static_network_reservation) { Bosh::Director::DesiredNetworkReservation.new_static(instance_model, network, '192.168.1.2/32') }

      let(:should_create_swap_delete?) { false }

      before do
        allow(instance_plan).to receive(:should_create_swap_delete?).and_return(should_create_swap_delete?)
      end

      context 'when the instance group is on a dynamic network' do
        let(:network) { DynamicNetwork.new('my-network', subnets, '32', per_spec_logger) }
        let(:desired_reservations) { [dynamic_network_reservation] }
        let(:existing_reservations) { [Bosh::Director::ExistingNetworkReservation.new(instance_model, network, '192.168.1.2/32', 'dynamic')] }

        it 'uses the existing reservation' do
          existing_reservations.map { |reservation| reservation.resolve_type(:dynamic) }

          network_plans = network_planner.reconcile(existing_reservations)
          obsolete_plans = network_plans.select(&:obsolete?)
          existing_plans = network_plans.select(&:existing?)
          desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

          expect(desired_plans.count).to eq(0)
          expect(existing_plans.count).to eq(1)
          expect(obsolete_plans.count).to eq(0)
        end
      end

      context 'when the instance is a create-swap-delete instance' do
        let(:should_create_swap_delete?) { true }

        let(:desired_reservations) do
          [Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network)]
        end

        let(:existing_reservations) do
          [
            Bosh::Director::ExistingNetworkReservation.new(instance_model, network, '192.168.1.2/32', 'manual'),
          ]
        end

        context 'when desired reservation and existing reservations are dynamic' do
          before do
            existing_reservations.map { |reservation| reservation.resolve_type(:dynamic) }
            allow(instance_plan).to receive(:recreate_for_non_network_reasons?).and_return(false)
          end

          it 'reuses the existing reservation' do
            network_plans = network_planner.reconcile(existing_reservations)
            obsolete_plans = network_plans.select(&:obsolete?)
            existing_plans = network_plans.select(&:existing?)
            desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

            expect(desired_plans.count).to eq(0)
            expect(existing_plans.count).to eq(1)
            expect(obsolete_plans.count).to eq(0)
          end
        end

        context 'when desired reservation is dynamic but existing reservation is static' do
          before do
            existing_reservations.map { |reservation| reservation.resolve_type(:static) }
          end

          context 'when instance does not need recreate for non-network reasons' do
            before do
              allow(instance_plan).to receive(:recreate_for_non_network_reasons?).and_return(false)
            end

            let(:desired_reservations) do
              [Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network)]
            end

            it 'does not reuse the existing reservation' do
              network_plans = network_planner.reconcile(existing_reservations)
              obsolete_plans = network_plans.select(&:obsolete?)
              existing_plans = network_plans.select(&:existing?)
              desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

              expect(desired_plans.count).to eq(1)
              expect(existing_plans.count).to eq(0)
              expect(obsolete_plans.count).to eq(1)
            end
          end
        end

        context 'when instance needs recreate for non-network or network allocation reasons' do
          context 'when there is a non-network reason to recreate' do
            before do
              allow(instance_plan).to receive(:recreate_for_non_network_reasons?).and_return(true)
            end

            it 'does not reuse the existing reservation' do
              network_plans = network_planner.reconcile(existing_reservations)
              obsolete_plans = network_plans.select(&:obsolete?)
              existing_plans = network_plans.select(&:existing?)
              desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

              expect(desired_plans.count).to eq(1)
              expect(existing_plans.count).to eq(0)
              expect(obsolete_plans.count).to eq(1)
            end
          end

          context 'when there are new networks to be added to the instance(s)' do
            before do
              allow(instance_plan).to receive(:recreate_for_non_network_reasons?).and_return(false)
            end

            let(:desired_reservations) do
              [Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network),
               Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network)]
            end

            it 'does not reuse the existing reservation' do
              network_plans = network_planner.reconcile(existing_reservations)
              obsolete_plans = network_plans.select(&:obsolete?)
              existing_plans = network_plans.select(&:existing?)
              desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

              expect(desired_plans.count).to eq(2)
              expect(existing_plans.count).to eq(0)
              expect(obsolete_plans.count).to eq(1)
            end
          end

          context 'when the instance plan has fewer desired networks than existing networks' do
            before do
              allow(instance_plan).to receive(:recreate_for_non_network_reasons?).and_return(false)
            end

            let(:existing_reservations) do
              [
                Bosh::Director::ExistingNetworkReservation.new(instance_model, network, '192.168.1.2/32', 'manual'),
                Bosh::Director::ExistingNetworkReservation.new(instance_model, network, '192.168.1.3/32', 'manual'),
              ]
            end

            let(:desired_reservations) do
              [Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network)]
            end

            it 'does not reuse the existing reservation' do
              network_plans = network_planner.reconcile(existing_reservations)
              obsolete_plans = network_plans.select(&:obsolete?)
              existing_plans = network_plans.select(&:existing?)
              desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

              expect(desired_plans.count).to eq(1)
              expect(existing_plans.count).to eq(0)
              expect(obsolete_plans.count).to eq(2)
            end
          end
        end
      end

      describe 'changes to specifications about the instances network' do
        let(:existing_reservations) { [Bosh::Director::ExistingNetworkReservation.new(instance_model, network, '192.168.1.2/32', 'manual')] }
        let(:desired_reservations) { [Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network2)] }

        before do
          existing_reservations[0].resolve_type(:dynamic)
        end

        context 'when the existing ip is part of a vip static network but the desired network is a global vip network' do
          let(:network) { VipNetwork.new('static-vip-network', nil, [], '32', per_spec_logger) }
          let(:network_spec) do
            {
              'name' => 'global-vip-network',
              'subnets' => [
                { 'static' => ['192.168.1.1', '192.168.1.2'], azs: [instance_model.availability_zone] },
              ],
            }
          end
          let(:network2) { VipNetwork.parse(network_spec, [], per_spec_logger) }

          let(:existing_reservations) { [Bosh::Director::ExistingNetworkReservation.new(instance_model, network, '192.168.1.2/32', 'vip')] }
          let(:initial_az) { 'zone_1' }
          it 'should keep the existing reservation' do
            network_plans = network_planner.reconcile(existing_reservations)
            obsolete_plans = network_plans.select(&:obsolete?)
            existing_plans = network_plans.select(&:existing?)
            desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

            expect(obsolete_plans.count).to eq(0)
            expect(existing_plans.count).to eq(1)
            expect(desired_plans.count).to eq(0)

            expect(existing_plans[0].reservation.network.name).to eq('global-vip-network')
            expect(existing_plans[0].reservation.instance_model).to eq(instance_model)
            expect(existing_plans[0].reservation.ip).to eq('192.168.1.2')
          end
        end

        context 'when the network name changes' do
          let(:initial_az) { 'zone_1' }
          let(:network2) { ManualNetwork.new('my-network-2', subnets, '32', per_spec_logger) }

          it 'should keep existing reservations' do
            network_plans = network_planner.reconcile(existing_reservations)
            obsolete_plans = network_plans.select(&:obsolete?)
            existing_plans = network_plans.select(&:existing?)
            desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

            expect(obsolete_plans.count).to eq(0)
            expect(existing_plans.count).to eq(1)
            expect(desired_plans.count).to eq(0)

            expect(existing_plans[0].reservation.network.name).to eq('my-network-2')
            expect(existing_plans[0].reservation.instance_model).to eq(instance_model)
            expect(existing_plans[0].reservation.ip).to eq('192.168.1.2')
          end

          context 'and the new network does not match az' do
            let(:desired_az) { AvailabilityZone.new('zone_2', {}) }
            it 'should have a new reservation' do
              network_plans = network_planner.reconcile(existing_reservations)
              obsolete_plans = network_plans.select(&:obsolete?)
              existing_plans = network_plans.select(&:existing?)
              desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

              expect(obsolete_plans.count).to eq(1)
              expect(existing_plans.count).to eq(0)
              expect(desired_plans.count).to eq(1)

              expect(desired_plans[0].reservation.network.name).to eq('my-network-2')
              expect(desired_plans[0].reservation.instance_model).to eq(instance_model)
            end
          end

          context 'and the new network has no AZ' do
            let(:subnets) do
              [
                ManualNetworkSubnet.new(
                  'my-network',
                  IPAddr.new('192.168.1.0/24'),
                  nil, nil, nil, nil, [], [],
                  ['192.168.1.10'], '32'
                ),
              ]
            end

            it 'should have a new reservation' do
              network_plans = network_planner.reconcile(existing_reservations)
              obsolete_plans = network_plans.select(&:obsolete?)
              existing_plans = network_plans.select(&:existing?)
              desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

              expect(obsolete_plans.count).to eq(1)
              expect(existing_plans.count).to eq(0)
              expect(desired_plans.count).to eq(1)

              expect(desired_plans[0].reservation.network.name).to eq('my-network-2')
              expect(desired_plans[0].reservation.instance_model).to eq(instance_model)
            end
          end
        end

        context 'when the instance model has no az' do
          let(:initial_az) { '' }
          let(:desired_az) { nil }
          let(:network2) { ManualNetwork.new('my-network-2', subnets, '32', per_spec_logger) }
          let(:subnets) do
            [
              ManualNetworkSubnet.new(
                'my-network',
                IPAddr.new('192.168.1.0/24'),
                nil, nil, nil, nil, [], [],
                ['192.168.1.10'], nil, nil, '32'
              ),
            ]
          end

          it 'should use the existing reservation' do
            network_plans = network_planner.reconcile(existing_reservations)
            obsolete_plans = network_plans.select(&:obsolete?)
            existing_plans = network_plans.select(&:existing?)
            desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

            expect(obsolete_plans.count).to eq(0)
            expect(existing_plans.count).to eq(1)
            expect(desired_plans.count).to eq(0)

            expect(existing_plans[0].reservation.network.name).to eq('my-network-2')
            expect(existing_plans[0].reservation.instance_model).to eq(instance_model)
          end
        end

        context 'when the network type changes to dynamic' do
          let(:network2) { DynamicNetwork.new('my-network-2', subnets, '32', per_spec_logger) }

          it 'should have a new reservation' do
            network_plans = network_planner.reconcile(existing_reservations)
            obsolete_plans = network_plans.select(&:obsolete?)
            existing_plans = network_plans.select(&:existing?)
            desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

            expect(obsolete_plans.count).to eq(1)
            expect(existing_plans.count).to eq(0)
            expect(desired_plans.count).to eq(1)

            expect(obsolete_plans[0].reservation.network.name).to eq('my-network')
            expect(desired_plans[0].reservation.network.name).to eq('my-network-2')
          end
        end

        context 'when the network type changes to manual' do
          let(:network) { DynamicNetwork.new('my-network', subnets, '32', per_spec_logger) }
          let(:network2) { ManualNetwork.new('my-network-2', subnets, '32', per_spec_logger) }

          it 'should have a new reservation' do
            network_plans = network_planner.reconcile(existing_reservations)
            obsolete_plans = network_plans.select(&:obsolete?)
            existing_plans = network_plans.select(&:existing?)
            desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

            expect(obsolete_plans.count).to eq(1)
            expect(existing_plans.count).to eq(0)
            expect(desired_plans.count).to eq(1)

            expect(obsolete_plans[0].reservation.network.name).to eq('my-network')
            expect(desired_plans[0].reservation.network.name).to eq('my-network-2')
          end
        end
      end

      context 'when desired reservations are the same as existing ones' do
        let(:desired_reservations) do
          [
            static_network_reservation,
            dynamic_network_reservation,
          ]
        end

        before do
          existing_reservations[0].resolve_type(:static)
          existing_reservations[1].resolve_type(:dynamic)
        end

        it 'should keep existing reservation and return no desired new or obsolete network plans' do
          network_plans = network_planner.reconcile(existing_reservations)
          obsolete_plans = network_plans.select(&:obsolete?)
          existing_plans = network_plans.select(&:existing?)
          desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

          expect(desired_plans.count).to eq(0)
          expect(existing_plans.count).to eq(2)
          expect(obsolete_plans.count).to eq(0)
        end

        context 'when the order of IPs changed' do
          let(:static_network_reservation1) { Bosh::Director::DesiredNetworkReservation.new_static(instance_model, network, '192.168.1.3') }
          let(:static_network_reservation2) { Bosh::Director::DesiredNetworkReservation.new_static(instance_model, network, '192.168.1.4') }
          let(:desired_reservations) do
            [
              static_network_reservation2,
              static_network_reservation1,
            ]
          end

          before do
            existing_reservations[0].resolve_type(:static)
            existing_reservations[1].resolve_type(:static)
          end

          it 'should keep existing reservation that match IP address' do
            network_plans = network_planner.reconcile(existing_reservations)
            obsolete_plans = network_plans.select(&:obsolete?)
            existing_plans = network_plans.select(&:existing?)
            desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

            expect(obsolete_plans.count).to eq(1)
            expect(obsolete_plans.first.reservation.ip).to eq('192.168.1.2')
            expect(existing_plans.count).to eq(1)
            expect(existing_plans.first.reservation.ip).to eq('192.168.1.3')
            expect(desired_plans.count).to eq(1)
            expect(desired_plans.first.reservation.ip).to eq('192.168.1.4')
          end
        end
      end

      context 'when existing reservation availability zones do not match job availability zones' do
        let(:desired_az) { AvailabilityZone.new('zone_2', {}) }
        let(:existing_reservations) { [Bosh::Director::ExistingNetworkReservation.new(instance_model, network, '192.168.1.2/32', 'manual')] }
        let(:desired_reservations) { [Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network)] }

        before { existing_reservations[0].resolve_type(:dynamic) }

        it 'not reusing existing reservations' do
          network_plans = network_planner.reconcile(existing_reservations)
          obsolete_plans = network_plans.select(&:obsolete?)
          existing_plans = network_plans.select(&:existing?)
          desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

          expect(obsolete_plans.count).to eq(1)
          expect(obsolete_plans.first.reservation.ip).to eq('192.168.1.2')
          expect(existing_plans.count).to eq(0)
          expect(desired_plans.count).to eq(1)
          expect(desired_plans.first.reservation.type).to eq(:dynamic)
        end

        context 'when desired instance does not yet have an availability zone' do
          let(:desired_az) { nil }
          it 'does not raise an error' do
            allow(per_spec_logger).to receive(:debug)

            expect(per_spec_logger).to receive(:debug)
              .with('Existing reservation belongs to azs: ["zone_1"], desired az is nil')
            expect(per_spec_logger).to receive(:debug)
              .with(/Can't reuse reservation .*, existing reservation az does not match desired az ''/)
            network_planner.reconcile(existing_reservations)
          end
        end
      end

      context 'when existing reservation and job do not belong to any availability zone' do
        let(:desired_az) { nil }
        let(:existing_reservations) { [Bosh::Director::ExistingNetworkReservation.new(instance_model, network, '192.168.1.2/32', 'manual')] }
        let(:desired_reservations) { [Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network)] }
        let(:subnets) do
          [
            ManualNetworkSubnet.new(
              'my-network',
              IPAddr.new('192.168.1.0/24'),
              nil, nil, nil, nil, nil, [],
              ['192.168.1.10'],
              nil, nil,
              '32'
            ),
          ]
        end

        before { existing_reservations[0].resolve_type(:dynamic) }

        it 'reusing existing reservations' do
          network_plans = network_planner.reconcile(existing_reservations)
          obsolete_plans = network_plans.select(&:obsolete?)
          existing_plans = network_plans.select(&:existing?)
          desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

          expect(obsolete_plans.count).to eq(0)
          expect(existing_plans.count).to eq(1)
          expect(existing_plans.first.reservation.ip).to eq('192.168.1.2/32')
          expect(desired_plans.count).to eq(0)
        end
      end

      context 'when there are new reservations' do
        let(:dynamic_network_reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network) }
        let(:desired_reservations) do
          [
            Bosh::Director::DesiredNetworkReservation.new_static(instance_model, network, '192.168.1.2/32'),
            Bosh::Director::DesiredNetworkReservation.new_static(instance_model, network, '192.168.1.4/32'),
            dynamic_network_reservation,
          ]
        end

        before do
          existing_reservations[0].resolve_type(:static)
          existing_reservations[1].resolve_type(:dynamic)
        end

        it 'should return desired network plans for the new reservations' do
          network_plans = network_planner.reconcile(existing_reservations)
          obsolete_plans = network_plans.select(&:obsolete?)
          existing_plans = network_plans.select(&:existing?)
          desired_plans = network_plans.reject(&:existing?).reject(&:obsolete?)

          expect(desired_plans.count).to eq(1)
          expect(existing_plans.count).to eq(2)
          expect(obsolete_plans.count).to eq(0)
        end
      end

      context 'when there is no desired reservations' do
        let(:dynamic_network_reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network) }
        let(:desired_reservations) { [] }

        before do
          existing_reservations[0].resolve_type(:static)
          existing_reservations[1].resolve_type(:dynamic)
        end

        it 'should return desired network plans for the new reservations' do
          network_plans = network_planner.reconcile(existing_reservations)
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
