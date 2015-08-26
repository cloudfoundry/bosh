require 'spec_helper'

describe Bosh::Director::DeploymentPlan::IpProviderV2 do
  describe '#delete' do
    it 'releases the ip' do
      ip_repo = instance_double(BD::DeploymentPlan::IpRepoThatDelegatesToExistingStuff)
      allow(ip_repo).to receive(:delete)

      ip_provider = BD::DeploymentPlan::IpProviderV2.new(ip_repo)

      ip = NetAddr::CIDR.create('192.168.1.1')
      network = instance_double(BD::DeploymentPlan::ManualNetwork)

      ip_provider.delete(ip, network)

      expect(ip_repo).to have_received(:delete).with(ip, network)
    end
  end
end
