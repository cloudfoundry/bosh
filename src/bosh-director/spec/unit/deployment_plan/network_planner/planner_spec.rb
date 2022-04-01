require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe NetworkPlanner::Planner do
    include Bosh::Director::IpUtil

    subject(:planner) { NetworkPlanner::Planner.new(logger) }
    let(:instance_plan) { InstancePlan.new(existing_instance: nil, desired_instance: desired_instance, instance: instance, variables_interpolator: variables_interpolator) }
    let(:variables_interpolator) { double(Bosh::Director::ConfigServer::VariablesInterpolator) }
    let(:deployment) { instance_double(Planner, model: Bosh::Director::Models::Deployment.make) }
    let(:desired_instance) { DesiredInstance.new(instance_group, deployment) }
    let(:instance_model) { Bosh::Director::Models::Instance.make }
    let(:instance_group) { InstanceGroup.make }
    let(:instance_repository) { InstanceRepository.new(logger, variables_interpolator) }
    let(:instance) { instance_repository.fetch_existing(instance_model, {}, desired_instance) }
    let(:deployment_subnets) do
      [
        ManualNetworkSubnet.new(
          'network_A',
          NetAddr::IPv4Net.parse('192.168.1.0/24'),
          nil, nil, nil, nil, ['zone_1'], [],
          ['192.168.1.10', '192.168.1.11', '192.168.1.12', '192.168.1.13', '192.168.1.14']
        ),
      ]
    end
    let(:deployment_network) { ManualNetwork.new('network_A', deployment_subnets, nil) }
    let(:instance_group_network) { JobNetwork.make(name: 'network_A', deployment_network: deployment_network) }

    describe 'network_plan_with_dynamic_reservation' do
      it 'creates network plan for requested instance plan and network' do
        network_plan = planner.network_plan_with_dynamic_reservation(instance_plan, instance_group_network)
        expect(network_plan.reservation.dynamic?).to be_truthy
        expect(network_plan.reservation.instance_model).to eq(instance_model)
        expect(network_plan.reservation.network).to eq(deployment_network)
      end
    end

    describe 'network_plan_with_static_reservation' do
      it 'creates network plan with provided IP' do
        network_plan = planner.network_plan_with_static_reservation(instance_plan, instance_group_network, '192.168.2.10')
        expect(network_plan.reservation.static?).to be_truthy
        expect(network_plan.reservation.instance_model).to eq(instance_model)
        expect(network_plan.reservation.ip).to eq(ip_to_i('192.168.2.10'))
        expect(network_plan.reservation.network).to eq(deployment_network)
      end
    end
  end
end
