require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe PlacementPlanner::Plan do
    subject(:plan) { PlacementPlanner::Plan.new(instance_plan_factory, network_planner, logger) }
    let(:network_planner) { NetworkPlanner::Planner.new(logger) }
    let(:network_reservation_repository) { BD::DeploymentPlan::NetworkReservationRepository.new(deployment, logger) }
    let(:instance_plan_factory) { InstancePlanFactory.new(instance_repo, {}, SkipDrain.new(true), index_assigner, network_reservation_repository) }
    let(:index_assigner) { PlacementPlanner::IndexAssigner.new(deployment_model) }
    let(:instance_repo) { Bosh::Director::DeploymentPlan::InstanceRepository.new(network_reservation_repository, logger) }
    let(:instance_plans) do
      plan.create_instance_plans(desired, existing, job_networks, availability_zones, 'jobname')
    end
    let(:availability_zones) { [zone_1, zone_2] }
    let(:zone_1) {AvailabilityZone.new('zone_1', {})}
    let(:zone_2) {AvailabilityZone.new('zone_2', {})}
    let(:zone_3) {AvailabilityZone.new('zone_3', {})}
    let(:job) do
      job = InstanceGroup.new(logger)
      job.name = 'db'
      job
    end

    let(:desired) { [DesiredInstance.new(job, deployment), DesiredInstance.new(job, deployment), DesiredInstance.new(job, deployment)] }
    let(:existing) {
      [
        existing_instance_with_az(2, zone_1.name),
        existing_instance_with_az(0, zone_3.name),
        existing_instance_with_az(1, zone_2.name)
      ]
    }
    let(:deployment) { instance_double(Planner, model: deployment_model) }
    let(:deployment_model) {  Bosh::Director::Models::Deployment.make }

    let(:deployment_network) { ManualNetwork.new('network_A', deployment_subnets, nil) }
    let(:deployment_subnets) { [
      ManualNetworkSubnet.new(
        'network_A',
        NetAddr::CIDR.create('192.168.1.0/24'),
        nil, nil, nil, nil, ['zone_1'], [],
        ['192.168.1.10', '192.168.1.11', '192.168.1.12', '192.168.1.13', '192.168.1.14']),
      ManualNetworkSubnet.new(
        'network_A',
        NetAddr::CIDR.create('10.10.1.0/24'),
        nil, nil, nil, nil, ['zone_2'], [],
        ['10.10.1.10', '10.10.1.11', '10.10.1.12', '10.10.1.13', '10.10.1.14']),
      ManualNetworkSubnet.new(
        'network_A',
        NetAddr::CIDR.create('10.0.1.0/24'),
        nil, nil, nil, nil, ['zone_3'], [],
        ['10.0.1.10', '10.0.1.11', '10.0.1.12', '10.0.1.13', '10.0.1.14']),
    ] }
    let(:job_networks) { [JobNetwork.new('network_A', job_static_ips, [], deployment_network)] }

    context 'when job networks include static IPs' do
      let(:job_static_ips) {['192.168.1.10', '192.168.1.11', '10.10.1.10']}

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
      DesiredInstance.new(job, 'started', nil, zone)
    end
  end
end
