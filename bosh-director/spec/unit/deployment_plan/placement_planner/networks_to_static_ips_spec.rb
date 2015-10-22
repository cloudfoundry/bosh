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
          }.to raise_error Bosh::Director::JobInvalidAvailabilityZone, "Job 'fake-job' subnets declare availability zones and the job does not"
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
      context 'when there are AZs that are declared in job networks but not in desired azs'do
        let(:desired_azs) do
          [
            AvailabilityZone.new('z1', {}),
            AvailabilityZone.new('z3', {}),
          ]
        end

        it 'raises an error' do
          expect {
            networks_to_static_ips.validate_ips_are_in_desired_azs(desired_azs)
          }.to raise_error Bosh::Director::JobStaticIpsFromInvalidAvailabilityZone,
            "Job 'fake-job' declares static ip '192.168.0.1' which does not belong to any of the job's availability zones."
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
    end
  end
end
