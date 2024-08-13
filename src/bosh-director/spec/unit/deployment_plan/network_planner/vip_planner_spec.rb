require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::NetworkPlanner::VipPlanner do
    include IpUtil

    subject(:planner) { DeploymentPlan::NetworkPlanner::VipPlanner.new(network_planner, logger) }

    let(:network_planner) { DeploymentPlan::NetworkPlanner::Planner.new(logger) }
    let(:deployment_model) { FactoryBot.create(:models_deployment, name: 'my-deployment') }
    let(:variables_interpolator) { double(Bosh::Director::ConfigServer::VariablesInterpolator) }

    let(:instance_plans) { [instance_plan] }

    let(:instance_plan) { make_instance_plan }

    let(:instance_group) { FactoryBot.build(:deployment_plan_instance_group) }

    def make_instance_plan
      instance_model = Models::Instance.make
      instance = DeploymentPlan::Instance.create_from_instance_group(
        instance_group,
        instance_model.index,
        'started',
        deployment_model,
        {},
        nil,
        logger,
        variables_interpolator,
      )

      instance.bind_existing_instance_model(instance_model)
      DeploymentPlan::InstancePlan.new(
        existing_instance: instance_model,
        desired_instance: DeploymentPlan::DesiredInstance.new,
        instance: instance,
        network_plans: [],
        variables_interpolator: variables_interpolator,
      )
    end

    context 'when there are vip networks' do
      let(:vip_networks) { [vip_network1, vip_network2] }

      let(:vip_network1) do
        DeploymentPlan::JobNetwork.new(
          'fake-network-1',
          instance_group_static_ips1,
          [],
          vip_deployment_network1,
        )
      end

      let(:vip_network2) do
        DeploymentPlan::JobNetwork.new(
          'fake-network-2',
          instance_group_static_ips2,
          [],
          vip_deployment_network2,
        )
      end

      let(:vip_deployment_network1) do
        DeploymentPlan::VipNetwork.parse(vip_network_spec1, [], logger)
      end

      let(:vip_deployment_network2) do
        DeploymentPlan::VipNetwork.parse(vip_network_spec2, [], logger)
      end

      context 'and there are static ips defined only on the job network' do
        let(:instance_group_static_ips1) { [ip_to_i('68.68.68.68'), ip_to_i('69.69.69.69')] }
        let(:instance_group_static_ips2) { [ip_to_i('77.77.77.77'), ip_to_i('79.79.79.79')] }
        let(:vip_network_spec1) { { 'name' => 'vip-network-1' } }
        let(:vip_network_spec2) { { 'name' => 'vip-network-2' } }

        it 'creates network plans with static IP from each vip network' do
          planner.add_vip_network_plans(instance_plans, vip_networks)
          expect(instance_plan.network_plans[0].reservation.ip).to eq(ip_to_i('68.68.68.68'))
          expect(instance_plan.network_plans[0].reservation.network).to eq(vip_deployment_network1)

          expect(instance_plan.network_plans[1].reservation.ip).to eq(ip_to_i('77.77.77.77'))
          expect(instance_plan.network_plans[1].reservation.network).to eq(vip_deployment_network2)
        end

        context 'when instance already has vip networks' do
          context 'when existing instance IPs can be reused' do
            before do
              Models::IpAddress.make(
                address_str: ip_to_i('69.69.69.69').to_s,
                network_name: 'fake-network-1',
                instance: instance_plan.existing_instance,
              )

              Models::IpAddress.make(
                address_str: ip_to_i('79.79.79.79').to_s,
                network_name: 'fake-network-2',
                instance: instance_plan.existing_instance,
              )
            end

            it 'assigns vip static IP that instance is currently using' do
              planner.add_vip_network_plans(instance_plans, vip_networks)
              expect(instance_plan.network_plans[0].reservation.ip).to eq(ip_to_i('69.69.69.69'))
              expect(instance_plan.network_plans[0].reservation.network).to eq(vip_deployment_network1)

              expect(instance_plan.network_plans[1].reservation.ip).to eq(ip_to_i('79.79.79.79'))
              expect(instance_plan.network_plans[1].reservation.network).to eq(vip_deployment_network2)
            end
          end

          context 'when existing instance static IP is no longer in the list of IPs' do
            before do
              Models::IpAddress.make(
                address_str: ip_to_i('65.65.65.65').to_s,
                network_name: 'fake-network-1',
                instance: instance_plan.existing_instance,
              )

              Models::IpAddress.make(
                address_str: ip_to_i('79.79.79.79').to_s,
                network_name: 'fake-network-2',
                instance: instance_plan.existing_instance,
              )
            end

            it 'picks new IP for instance' do
              planner.add_vip_network_plans(instance_plans, vip_networks)
              instance_plan = instance_plans.first
              expect(instance_plan.network_plans[0].reservation.ip).to eq(ip_to_i('68.68.68.68'))
              expect(instance_plan.network_plans[0].reservation.network).to eq(vip_deployment_network1)

              expect(instance_plan.network_plans[1].reservation.ip).to eq(ip_to_i('79.79.79.79'))
              expect(instance_plan.network_plans[1].reservation.network).to eq(vip_deployment_network2)
            end
          end

          context 'with several instances' do
            let(:instance_plans) do
              [make_instance_plan, make_instance_plan]
            end

            before do
              Models::IpAddress.make(
                address_str: ip_to_i('68.68.68.68').to_s,
                network_name: 'fake-network-1',
                instance: instance_plans[1].existing_instance,
              )

              Models::IpAddress.make(
                address_str: ip_to_i('77.77.77.77').to_s,
                network_name: 'fake-network-2',
                instance: instance_plans[1].existing_instance,
              )
            end

            it 'properly assigns vip IPs based on current instance IPs' do
              planner.add_vip_network_plans(instance_plans, vip_networks)
              first_instance_plan = instance_plans[0]
              expect(first_instance_plan.network_plans[0].reservation.ip).to eq(ip_to_i('69.69.69.69'))
              expect(first_instance_plan.network_plans[0].reservation.network).to eq(vip_deployment_network1)
              expect(first_instance_plan.network_plans[1].reservation.ip).to eq(ip_to_i('79.79.79.79'))
              expect(first_instance_plan.network_plans[1].reservation.network).to eq(vip_deployment_network2)

              second_instance_plan = instance_plans[1]
              expect(second_instance_plan.network_plans[0].reservation.ip).to eq(ip_to_i('68.68.68.68'))
              expect(second_instance_plan.network_plans[0].reservation.network).to eq(vip_deployment_network1)
              expect(second_instance_plan.network_plans[1].reservation.ip).to eq(ip_to_i('77.77.77.77'))
              expect(second_instance_plan.network_plans[1].reservation.network).to eq(vip_deployment_network2)
            end
          end
        end
      end

      context 'and there are static ips defined only on network in the cloud config' do
        let(:instance_group_static_ips1) { [] }
        let(:instance_group_static_ips2) { [] }

        let(:vip_network_spec1) do
          {
            'name' => 'vip-network-1',
            'subnets' => [{ 'static' => ['68.68.68.68', '69.69.69.69'] }],
          }
        end

        let(:vip_network_spec2) do
          {
            'name' => 'vip-network-2',
            'subnets' => [{ 'static' => ['77.77.77.77', '79.79.79.79'] }],
          }
        end

        it 'creates a dynamic reservation' do
          planner.add_vip_network_plans(instance_plans, vip_networks)
          expect(instance_plan.network_plans[0].reservation.network).to eq(vip_deployment_network1)
          expect(instance_plan.network_plans[0].reservation.type).to eq(:dynamic)

          expect(instance_plan.network_plans[1].reservation.network).to eq(vip_deployment_network2)
          expect(instance_plan.network_plans[1].reservation.type).to eq(:dynamic)
        end
      end

      context 'and there are static ips defined on the job network and in the network in the cloud config' do
        let(:instance_group_static_ips1) { [ip_to_i('68.68.68.68'), ip_to_i('69.69.69.69')] }
        let(:instance_group_static_ips2) { [] }
        let(:vip_network_spec1) { { 'name' => 'vip-network-1', 'subnets' => [{ 'static' => ['1.1.1.1'] }] } }
        let(:vip_network_spec2) { { 'name' => 'vip-network-2' } }

        it 'raises an error' do
          expect do
            planner.add_vip_network_plans(instance_plans, vip_networks)
          end.to raise_error(
            NetworkReservationVipMisconfigured,
            'IPs cannot be specified in both the instance group and the cloud config',
          )
        end
      end
    end

    context 'when there are no vip networks' do
      let(:vip_networks) { [] }

      it 'does not modify instance plans' do
        planner.add_vip_network_plans(instance_plans, vip_networks)
        expect(instance_plans).to eq(instance_plans)
      end
    end
  end
end
