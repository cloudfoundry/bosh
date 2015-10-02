require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe PlacementPlanner::Plan do
    subject(:plan) { PlacementPlanner::Plan.new(desired, existing, job_networks, availability_zones) }

    let(:desired)            { [desired_instance, desired_instance, desired_instance] }
    let(:existing)           { [] }
    let(:deployment_network) { ManualNetwork.new('a', deployment_subnets, nil) }
    let(:deployment_subnets) { [ManualNetworkSubnet.new('a', NetAddr::CIDR.create('192.168.2.0/24'), nil, nil, nil, nil, [], [], ['192.168.1.10', '192.168.1.11', '192.168.1.12', '192.168.1.13', '192.168.1.14'])] }
    let(:job_networks)       { [JobNetwork.new('a', ['192.168.1.10', '192.168.1.11', '192.168.1.12'], [], deployment_network)] }

    context 'when availability zones are not specified' do
      let(:availability_zones) { [] }

      describe '#needed' do
        it 'does something' do
          expect(plan.needed.map(&:az)).to eq([nil, nil, nil])
        end
      end
    end

    private

    def desired_instance
      DesiredInstance.new
    end
  end
end
