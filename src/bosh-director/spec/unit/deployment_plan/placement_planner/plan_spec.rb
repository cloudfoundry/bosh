require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe PlacementPlanner::Plan do
    subject(:plan) { PlacementPlanner::Plan.new(instance_plan_factory, network_planner, logger) }
    let(:network_planner) { NetworkPlanner::Planner.new(logger) }
    let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }

    let(:instance_plan_factory) do
      InstancePlanFactory.new(
        instance_repo,
        {},
        deployment,
        index_assigner,
        variables_interpolator,
        [],
      )
    end

    let(:index_assigner) { PlacementPlanner::IndexAssigner.new(deployment_model) }
    let(:instance_repo) { Bosh::Director::DeploymentPlan::InstanceRepository.new(logger, variables_interpolator) }
    let(:instance_plans) do
      plan.create_instance_plans(desired, existing, job_networks, availability_zones, 'jobname')
    end
    let(:availability_zones) { [zone_1, zone_2] }
    let(:zone_1) { AvailabilityZone.new('zone_1', {}) }
    let(:zone_2) { AvailabilityZone.new('zone_2', {}) }
    let(:zone_3) { AvailabilityZone.new('zone_3', {}) }

    let(:instance_group) { InstanceGroup.make }

    let(:desired) do
      [
        DesiredInstance.new(instance_group, deployment),
        DesiredInstance.new(instance_group, deployment),
        DesiredInstance.new(instance_group, deployment),
      ]
    end
    let(:existing) do
      [
        existing_instance_with_az(2, zone_1.name),
        existing_instance_with_az(0, zone_3.name),
        existing_instance_with_az(1, zone_2.name),
      ]
    end
    let(:deployment) { instance_double(Planner, model: deployment_model, skip_drain: SkipDrain.new(true)) }
    let(:deployment_model) { Bosh::Director::Models::Deployment.make }

    let(:deployment_network) { ManualNetwork.new('network_A', deployment_subnets, nil) }
    let(:deployment_subnets) do
      [
        ManualNetworkSubnet.new(
          'network_A',
          NetAddr::IPv4Net.parse('192.168.1.0/24'),
          nil, nil, nil, nil, ['zone_1'], [],
          %w[
            192.168.1.10
            192.168.1.11
            192.168.1.12
            192.168.1.13
            192.168.1.14
          ]
        ),
        ManualNetworkSubnet.new(
          'network_A',
          NetAddr::IPv4Net.parse('10.10.1.0/24'),
          nil, nil, nil, nil, ['zone_2'], [],
          %w[
            10.10.1.10
            10.10.1.11
            10.10.1.12
            10.10.1.13
            10.10.1.14
          ]
        ),
        ManualNetworkSubnet.new(
          'network_A',
          NetAddr::IPv4Net.parse('10.0.1.0/24'),
          nil, nil, nil, nil, ['zone_3'], [],
          %w[
            10.0.1.10
            10.0.1.11
            10.0.1.12
            10.0.1.13
            10.0.1.14
          ]
        ),
      ]
    end
    let(:job_networks) do
      [JobNetwork.make(name: 'network_A', static_ips: job_static_ips, deployment_network: deployment_network)]
    end

    before do
      Bosh::Director::Models::VariableSet.make(deployment: deployment_model)
    end

    context 'when job networks include static IPs' do
      let(:job_static_ips) { ['192.168.1.10', '192.168.1.11', '10.10.1.10'] }

      it 'places the instances in azs there static IPs are in order of their indexes' do
        expect(instance_plans.select(&:new?).map(&:desired_instance).map(&:az)).to eq([zone_1])

        expect(instance_plans.select(&:existing?).map(&:desired_instance).map(&:az)).to match_array([zone_1, zone_2])
        expect(instance_plans.select(&:existing?).map(&:existing_instance)).to match_array([existing[0], existing[2]])
        expect(instance_plans.select(&:existing?).map(&:desired_instance)).to match_array([desired[0], desired[1]])

        expect(instance_plans.select(&:obsolete?).map(&:existing_instance)).to match_array([existing[1]])
      end
    end

    context 'when job networks do not include static IPs' do
      let(:job_static_ips) { nil }

      it 'evenly distributes the instances' do
        expect(instance_plans.select(&:new?).map(&:desired_instance).map(&:az)).to eq([zone_1])

        expect(instance_plans.select(&:existing?).map(&:existing_instance)).to match_array([existing[0], existing[2]])
        expect(instance_plans.select(&:existing?).map(&:desired_instance)).to match_array([desired[0], desired[1]])
        expect(instance_plans.select(&:existing?).map(&:desired_instance).map(&:az)).to eq([zone_1, zone_2])

        expect(instance_plans.select(&:obsolete?).map(&:existing_instance)).to match_array([existing[1]])
      end
    end

    def existing_instance_with_az(index, az)
      Bosh::Director::Models::Instance.make(index: index, availability_zone: az)
    end

    def desired_instance(zone = nil)
      DesiredInstance.new(instance_group, nil, zone, nil)
    end
  end
end
