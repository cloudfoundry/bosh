require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe PlacementPlanner::Plan do
    subject(:plan) { PlacementPlanner::Plan.new(desired, existing, job_networks, availability_zones) }

    let(:availability_zones) { [zone_1, zone_2] }
    let(:zone_1) {AvailabilityZone.new('zone_1', {})}
    let(:zone_2) {AvailabilityZone.new('zone_2', {})}
    let(:zone_3) {AvailabilityZone.new('zone_3', {})}

    let(:desired) { [DesiredInstance.new, DesiredInstance.new, DesiredInstance.new] }
    let(:existing) {
      [
        existing_instance_with_az(2, zone_1.name),
        existing_instance_with_az(0, zone_3.name),
        existing_instance_with_az(1, zone_2.name)
      ]
    }

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
      let(:job_static_ips) {['192.168.1.10', '192.168.1.11', '192.168.1.12']}

      it 'assigns indexes to the instances' do
        expect(plan.needed.map(&:index)).to eq([3, 4])
        indexes = plan.existing.map { |existing| existing[:desired_instance].index }
        expect(indexes).to match_array([2])
      end

      it 'places the instances across the azs' do
        expect(plan.needed.map(&:az)).to eq([zone_1, zone_1])

        expect(plan.existing).to match_array([
              {existing_instance_model: existing[0].model, desired_instance: desired[0]}
            ])

        expect(plan.obsolete).to match_array([existing[1].model, existing[2].model])
      end
    end

    context 'when job networks do not include static IPs' do
      let(:job_static_ips) { nil }

      it 'assigns indexes to the instances' do
        expect(plan.needed.map(&:index)).to eq([3])
        indexes = plan.existing.map { |existing| existing[:desired_instance].index }
        expect(indexes).to match_array([1, 2])
      end

      it 'evenly distributes the instances' do
        expect(plan.needed.map(&:az)).to eq([zone_1])

        expect(plan.existing).to match_array([
              {existing_instance_model: existing[0].model, desired_instance: desired[0]},
              {existing_instance_model: existing[2].model, desired_instance: desired[1]}
            ])

        expect(plan.obsolete).to match_array([existing[1].model])
      end
    end

    def existing_instance_with_az(index, az)
      instance_model = Bosh::Director::Models::Instance.make(index: index)
      InstanceWithAZ.new(instance_model, az)
    end

    def desired_instance(zone = nil)
      DesiredInstance.new(nil, 'started', nil, zone)
    end
  end
end
