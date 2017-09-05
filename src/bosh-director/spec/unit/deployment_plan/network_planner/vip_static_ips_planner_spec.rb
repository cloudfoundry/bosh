require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::NetworkPlanner::VipStaticIpsPlanner do
    include IpUtil

    subject(:planner) { DeploymentPlan::NetworkPlanner::VipStaticIpsPlanner.new(network_planner, logger) }
    let(:network_planner) { DeploymentPlan::NetworkPlanner::Planner.new(logger) }
    let(:instance_plans) do
      [instance_plan]
    end

    let(:instance_plan) do
      make_instance_plan
    end

    def make_instance_plan
      instance_model = Models::Instance.make
      instance = DeploymentPlan::Instance.create_from_job(job, instance_model.index, 'started', deployment, {}, nil, logger)
      instance.bind_existing_instance_model(instance_model)
      DeploymentPlan::InstancePlan.new({
        existing_instance: instance_model,
        desired_instance: DeploymentPlan::DesiredInstance.new,
        instance: instance,
        network_plans: [],
      })
    end
    let(:deployment) { instance_double(DeploymentPlan::Planner) }
    let(:job) do
      job = DeploymentPlan::InstanceGroup.new(logger)
      job.name = 'fake-job'
      job
    end

    context 'when there are vip networks' do
      let(:vip_networks) { [vip_network_1, vip_network_2] }
      let(:vip_network_1) do
        DeploymentPlan::JobNetwork.new('fake-network-1', [ip_to_i('68.68.68.68'), ip_to_i('69.69.69.69')], [], vip_deployment_network_1)
      end
      let(:vip_network_2) do
        DeploymentPlan::JobNetwork.new('fake-network-2', [ip_to_i('77.77.77.77'),ip_to_i('79.79.79.79')], [], vip_deployment_network_2)
      end
      let(:vip_deployment_network_1) do
        DeploymentPlan::VipNetwork.new({'name' => 'fake-network-1'}, logger)
      end
      let(:vip_deployment_network_2) do
        DeploymentPlan::VipNetwork.new({'name' => 'fake-network-2'}, logger)
      end

      it 'creates network plans with static IP from each vip network' do
        planner.add_vip_network_plans(instance_plans, vip_networks)
        expect(instance_plan.network_plans[0].reservation.ip).to eq(ip_to_i('68.68.68.68'))
        expect(instance_plan.network_plans[0].reservation.network).to eq(vip_deployment_network_1)

        expect(instance_plan.network_plans[1].reservation.ip).to eq(ip_to_i('77.77.77.77'))
        expect(instance_plan.network_plans[1].reservation.network).to eq(vip_deployment_network_2)
      end

      context 'when instance already has vip networks' do
        context 'when existing instance IPs can be reused' do
          before do
            Models::IpAddress.make(address_str: ip_to_i('69.69.69.69').to_s, network_name: 'fake-network-1', instance: instance_plan.existing_instance)
            Models::IpAddress.make(address_str: ip_to_i('79.79.79.79').to_s, network_name: 'fake-network-2', instance: instance_plan.existing_instance)
          end

          it 'assigns vip static IP that instance is currently using' do
            planner.add_vip_network_plans(instance_plans, vip_networks)
            expect(instance_plan.network_plans[0].reservation.ip).to eq(ip_to_i('69.69.69.69'))
            expect(instance_plan.network_plans[0].reservation.network).to eq(vip_deployment_network_1)

            expect(instance_plan.network_plans[1].reservation.ip).to eq(ip_to_i('79.79.79.79'))
            expect(instance_plan.network_plans[1].reservation.network).to eq(vip_deployment_network_2)
          end
        end

        context 'when existing instance static IP is no longer in the list of IPs' do
          before do
            Models::IpAddress.make(address_str: ip_to_i('65.65.65.65').to_s, network_name: 'fake-network-1', instance: instance_plan.existing_instance)
            Models::IpAddress.make(address_str: ip_to_i('79.79.79.79').to_s, network_name: 'fake-network-2', instance: instance_plan.existing_instance)
          end

          it 'picks new IP for instance' do
            planner.add_vip_network_plans(instance_plans, vip_networks)
            instance_plan = instance_plans.first
            expect(instance_plan.network_plans[0].reservation.ip).to eq(ip_to_i('68.68.68.68'))
            expect(instance_plan.network_plans[0].reservation.network).to eq(vip_deployment_network_1)

            expect(instance_plan.network_plans[1].reservation.ip).to eq(ip_to_i('79.79.79.79'))
            expect(instance_plan.network_plans[1].reservation.network).to eq(vip_deployment_network_2)
          end
        end

        context 'with several instances' do
          let(:instance_plans) do
            [make_instance_plan, make_instance_plan]
          end

          before do
            Models::IpAddress.make(address_str: ip_to_i('68.68.68.68').to_s, network_name: 'fake-network-1', instance: instance_plans[1].existing_instance)
            Models::IpAddress.make(address_str: ip_to_i('77.77.77.77').to_s, network_name: 'fake-network-2', instance: instance_plans[1].existing_instance)
          end

          it 'properly assigns vip IPs based on current instance IPs' do
            planner.add_vip_network_plans(instance_plans, vip_networks)
            first_instance_plan = instance_plans[0]
            expect(first_instance_plan.network_plans[0].reservation.ip).to eq(ip_to_i('69.69.69.69'))
            expect(first_instance_plan.network_plans[0].reservation.network).to eq(vip_deployment_network_1)
            expect(first_instance_plan.network_plans[1].reservation.ip).to eq(ip_to_i('79.79.79.79'))
            expect(first_instance_plan.network_plans[1].reservation.network).to eq(vip_deployment_network_2)

            second_instance_plan = instance_plans[1]
            expect(second_instance_plan.network_plans[0].reservation.ip).to eq(ip_to_i('68.68.68.68'))
            expect(second_instance_plan.network_plans[0].reservation.network).to eq(vip_deployment_network_1)
            expect(second_instance_plan.network_plans[1].reservation.ip).to eq(ip_to_i('77.77.77.77'))
            expect(second_instance_plan.network_plans[1].reservation.network).to eq(vip_deployment_network_2)
          end
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
