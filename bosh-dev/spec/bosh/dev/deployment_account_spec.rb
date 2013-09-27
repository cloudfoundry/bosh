require 'spec_helper'
require 'bosh/dev/aws/deployment_account'

module Bosh::Dev::Aws
  describe DeploymentAccount do
    describe '#initialize' do
      subject(:account) { DeploymentAccount.new('fake-a1', deployments_repository) }

      let(:deployments_repository) do
        instance_double(
          'Bosh::Dev::Aws::DeploymentsRepository',
          path: '/tmp/deployments-repo',
          clone_or_update!: nil,
        )
      end

      let(:shell) { instance_double('Bosh::Core::Shell') }
      before do
        Bosh::Core::Shell.stub(new: shell)
        shell.stub(:run).with('. /tmp/deployments-repo/fake-a1/bosh_environment && echo $BOSH_USER').and_return("fake-username\n")
        shell.stub(:run).with('. /tmp/deployments-repo/fake-a1/bosh_environment && echo $BOSH_PASSWORD').and_return("fake-password\n")
      end

      its(:manifest_path) { should eq('/tmp/deployments-repo/fake-a1/deployments/bosh/bosh.yml') }
      its(:bosh_user)     { should eq('fake-username') }
      its(:bosh_password) { should eq('fake-password') }

      it "clones a deployment repository for the deployment's manifest & bosh_environment" do
        deployments_repository.should_receive(:clone_or_update!)
        account
      end
    end
  end
end
