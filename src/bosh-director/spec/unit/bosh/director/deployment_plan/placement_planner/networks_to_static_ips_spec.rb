require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe PlacementPlanner::NetworksToStaticIps do
    subject(:networks_to_static_ips) { described_class.new(networks_to_static_ips_hash, 'fake-job') }

    let(:networks_to_static_ips_hash) do
      {
        'network-1' => [
          PlacementPlanner::NetworksToStaticIps::StaticIpToAzs.new('192.168.0.1', ['z2', 'z1']),
          PlacementPlanner::NetworksToStaticIps::StaticIpToAzs.new('192.168.0.2', ['z2']),
        ],
        'network-2' => [
          PlacementPlanner::NetworksToStaticIps::StaticIpToAzs.new('192.168.0.3', ['z2']),
          PlacementPlanner::NetworksToStaticIps::StaticIpToAzs.new('192.168.0.4', ['z1']),
        ],
      }
    end

    describe '#validate_azs_are_declared_in_job_and_subnets' do
      context 'when there are AZs that are declared in job networks but not in desired azs'do
        let(:desired_azs) { nil }

        it 'raises an error' do
          expect {
            networks_to_static_ips.validate_azs_are_declared_in_job_and_subnets(desired_azs)
          }.to raise_error Bosh::Director::JobInvalidAvailabilityZone, "Instance group 'fake-job' subnets declare availability zones and the instance group does not"
        end
      end

      context 'when there are AZs that are declared in job networks and in desired azs'do
        let(:desired_azs) do
          [
            AvailabilityZone.new('z1', {}),
            AvailabilityZone.new('z2', {}),
          ]
        end

        it 'does not raise an error' do
          expect {
            networks_to_static_ips.validate_azs_are_declared_in_job_and_subnets(desired_azs)
          }.to_not raise_error
        end
      end
    end

    describe 'validate_ips_are_in_desired_azs' do
      context 'when there are no AZs that job can put its static ips in'do
        let(:desired_azs) do
          [
            AvailabilityZone.new('z3', {}),
          ]
        end

        it 'raises an error' do
          expect {
            networks_to_static_ips.validate_ips_are_in_desired_azs(desired_azs)
          }.to raise_error Bosh::Director::JobStaticIpsFromInvalidAvailabilityZone,
            "Instance group 'fake-job' declares static ip '192.168.0.1' which does not belong to any of the instance group's availability zones."
        end
      end

      context 'when job declares azs which is subset of azs on ip subnet' do
        let(:desired_azs) do
          [
              AvailabilityZone.new('z1', {}),
          ]
        end

        let(:networks_to_static_ips_hash) do
          {
              'network-1' => [
                  PlacementPlanner::NetworksToStaticIps::StaticIpToAzs.new('192.168.0.1', ['z2', 'z1']),
              ]
          }
        end

        it 'does not raise an error' do
          expect {
            networks_to_static_ips.validate_ips_are_in_desired_azs(desired_azs)
          }.to_not raise_error
        end
      end

      context 'when there are AZs that are declared in job networks and in desired azs'do
        let(:desired_azs) do
          [
            AvailabilityZone.new('z1', {}),
            AvailabilityZone.new('z2', {}),
          ]
        end

        it 'does not raise an error' do
          expect {
            networks_to_static_ips.validate_ips_are_in_desired_azs(desired_azs)
          }.to_not raise_error
        end
      end

      describe '#next_ip_for_network' do
        let(:deployment_subnets) do
          [
            ManualNetworkSubnet.new(
              'network_A',
              IPAddr.new('192.168.1.0/24'),
              nil, nil, nil, nil, subnet_azs, [],
              ['192.168.1.10', '192.168.1.11', '192.168.1.12', '192.168.1.13', '192.168.1.14'])
          ]
        end
        let(:deployment_network) { ManualNetwork.new('network_A', deployment_subnets, '32', nil) }
        let(:job_networks) do
          [FactoryBot.build(:deployment_plan_job_network, name: 'network_A', static_ips: job_static_ips, deployment_network: deployment_network)]
        end
        let(:job_static_ips) { ['192.168.1.10', '192.168.1.11'] }
        let(:desired_azs) { [AvailabilityZone.new('zone_1', {})] }
        let(:subnet_azs) { ['zone_1'] }
        it 'finds first unclaimed IP in network' do
          networks_to_static_ips = PlacementPlanner::NetworksToStaticIps.create(job_networks, desired_azs, 'fake-job')
          static_ip_to_azs = networks_to_static_ips.next_ip_for_network(job_networks[0])
          expect(static_ip_to_azs.ip).to eq('192.168.1.10')
          networks_to_static_ips.claim_in_az(static_ip_to_azs.ip, 'zone_1')

          static_ip_to_azs = networks_to_static_ips.next_ip_for_network(job_networks[0])
          expect(static_ip_to_azs.ip).to eq('192.168.1.11')
        end

        context 'when the job specifies a static ip that belongs to no subnet' do
          let(:job_static_ips) { ['192.168.1.10', '192.168.1.244'] }
          it 'raises' do
            expect {
              PlacementPlanner::NetworksToStaticIps.create(job_networks, desired_azs, 'fake-job')
            }.to raise_error(Bosh::Director::InstanceGroupNetworkInstanceIpMismatch,
                "Instance group 'fake-job' with network 'network_A' declares static ip '192.168.1.244', which belongs to no subnet")
          end
        end

        context 'when desired azs are subset of subnet azs' do
          let(:subnet_azs) { ['zone_2', 'zone_1'] }

          it 'returns static ip in desired az' do
            networks_to_static_ips = PlacementPlanner::NetworksToStaticIps.create(job_networks, desired_azs, 'fake-job')
            static_ip_to_azs = networks_to_static_ips.next_ip_for_network(job_networks[0])
            expect(static_ip_to_azs.ip).to eq('192.168.1.10')
            expect(static_ip_to_azs.az_names).to eq(['zone_1'])
          end
        end
      end
    end
  end
end
