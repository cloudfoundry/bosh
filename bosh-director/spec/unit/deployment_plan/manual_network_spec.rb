require 'spec_helper'

describe Bosh::Director::DeploymentPlan::ManualNetwork do
  let(:manifest) do
   manifest = Bosh::Spec::Deployments.legacy_manifest
   manifest['networks'].first['subnets'].first['range'] = network_range
   manifest['networks'].first['subnets'].first['reserved'] << '192.168.1.3'
   manifest['networks'].first['subnets'].first['static'] = static_ips
   manifest
  end
  let(:network_range) { '192.168.1.0/24' }
  let(:static_ips) { [] }
  let(:network_spec) { manifest['networks'].first }
  let(:planner_factory) { BD::DeploymentPlan::PlannerFactory.create(BD::Config.logger) }
  let(:deployment_plan) { planner_factory.create_from_manifest(manifest, nil, {}) }
  let(:global_network_resolver) { BD::DeploymentPlan::GlobalNetworkResolver.new(deployment_plan) }
  let(:instance) { instance_double(BD::DeploymentPlan::Instance, model: BD::Models::Instance.make) }

  subject(:manual_network) do
     BD::DeploymentPlan::ManualNetwork.parse(
       network_spec,
       [
         BD::DeploymentPlan::AvailabilityZone.new('zone_1', {}),
         BD::DeploymentPlan::AvailabilityZone.new('zone_2', {})
       ],
       global_network_resolver,
       logger
     )
   end

  describe :initialize do
    it 'should parse subnets' do
      expect(manual_network.subnets.size).to eq(1)
      subnet = manual_network.subnets.first
      expect(subnet).to be_an_instance_of BD::DeploymentPlan::ManualNetworkSubnet
      expect(subnet.network_name).to eq(manual_network.name)
      expect(subnet.range).to eq(NetAddr::CIDR.create('192.168.1.0/24'))
    end

    context 'when there are overlapping subnets' do
      let(:manifest) do
        manifest = Bosh::Spec::Deployments.legacy_manifest
        manifest['networks'].first['subnets'] << Bosh::Spec::Deployments.subnet({
            'range' => '192.168.1.0/28',
          })
        manifest
      end

      it 'should raise an error' do
        expect {
          manual_network
        }.to raise_error(Bosh::Director::NetworkOverlappingSubnets)
      end
    end
  end

  describe :network_settings do
    it 'should provide the network settings from the subnet' do
      reservation = BD::DesiredNetworkReservation.new_static(instance, manual_network, '192.168.1.2')

      expect(manual_network.network_settings(reservation, [])).to eq({
            'ip' => '192.168.1.2',
            'netmask' => '255.255.255.0',
            'cloud_properties' => {},
            'gateway' => '192.168.1.1',
            'dns' => ['192.168.1.1', '192.168.1.2'],
            'default' => []
          })
    end

    it 'should set the defaults' do
      reservation = BD::DesiredNetworkReservation.new_static(instance, manual_network, '192.168.1.2')

      expect(manual_network.network_settings(reservation)).to eq({
            'ip' => '192.168.1.2',
            'netmask' => '255.255.255.0',
            'cloud_properties' => {},
            'gateway' => '192.168.1.1',
            'dns' => ['192.168.1.1', '192.168.1.2'],
            'default' => ['dns', 'gateway']
          })
    end

    it 'should fail when there is no IP' do
      reservation = BD::DesiredNetworkReservation.new_dynamic(instance, manual_network)

      expect {
        manual_network.network_settings(reservation)
      }.to raise_error(/without an IP/)
    end
  end

  describe 'azs' do
    let(:network_spec) do
      Bosh::Spec::Deployments.network.merge(
        'subnets' => [
          {
            'range' => '10.1.0.0/24',
            'gateway' => '10.1.0.1',
            'az' => 'zone_1',
          },
          {
            'range' => '10.2.0.0/24',
            'gateway' => '10.2.0.1',
            'az' => 'zone_2'
          },
          {
            'range' => '10.4.0.0/24',
            'gateway' => '10.4.0.1',
            'az' => 'zone_1'
          },
        ]
      )
    end

    it 'returns availability zones specified by subnets' do
      expect(manual_network.availability_zones).to eq (['zone_1', 'zone_2'])
    end
  end

  describe 'validate_has_job' do
    let(:network_spec) do
      Bosh::Spec::Deployments.network.merge(
        'subnets' => [
          {
            'range' => '10.1.0.0/24',
            'gateway' => '10.1.0.1',
            'az' => 'zone_1',
          },
          {
            'range' => '10.2.0.0/24',
            'gateway' => '10.2.0.1',
            'az' => 'zone_2'
          },
        ]
      )
    end

    it 'returns true when all availability zone names are contained by subnets' do
      expect(manual_network.has_azs?([])).to eq(true)
      expect(manual_network.has_azs?(['zone_1'])).to eq(true)
      expect(manual_network.has_azs?(['zone_2'])).to eq(true)
      expect(manual_network.has_azs?(['zone_1', 'zone_2'])).to eq(true)
    end

    it 'returns false when any availability zone are not contained by a subnet' do
      expect(manual_network.has_azs?(['zone_1', 'zone_3', 'zone_2', 'zone_4'])).to eq(false)
    end

    it 'returns false when there are no subnets without az' do
      expect(manual_network.has_azs?([nil])).to eq(false)
    end

    it 'returns false when there are no subnets without az' do
      expect(manual_network.has_azs?(nil)).to eq(false)
    end

    context 'when there are no subnets' do
      let(:network_spec) do
        Bosh::Spec::Deployments.network.merge(
          'subnets' => []
        )
      end

      it 'returns true when az is nil' do
        expect(manual_network.has_azs?(nil)).to eq(true)
      end
    end
  end

  context 'when any subnet has AZs, then all subnets must contain AZs' do
    let(:network_spec) do
      Bosh::Spec::Deployments.network.merge(
        'subnets' => [
          {
            'range' => '10.10.1.0/24',
            'gateway' => '10.10.1.1',
            'az' => 'zone_1'
          },
          {
            'range' => '10.10.2.0/24',
            'gateway' => '10.10.2.1',
          }
        ]
      )
    end

    it 'raises an error' do
      expect {
        manual_network
      }.to raise_error(
          Bosh::Director::JobInvalidAvailabilityZone,
          "Subnets on network 'a' must all either specify availability zone or not"
        )
    end
  end
end
