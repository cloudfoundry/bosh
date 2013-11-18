require 'spec_helper'
require 'bosh/dev/deployments_repository'
require 'bosh/dev/aws/deployment_account'

module Bosh::Dev::Aws
  describe DeploymentAccount do
    subject(:account) { described_class.new('fake-a1', deployments_repository) }

    let(:deployments_repository) do
      instance_double(
        'Bosh::Dev::DeploymentsRepository',
        path: '/tmp/deployments-repo',
        clone_or_update!: nil,
      )
    end

    before { Bosh::Core::Shell.stub(new: shell) }
    let(:shell) { instance_double('Bosh::Core::Shell') }

    describe '#initialize' do
      before do
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

    describe '#run_with_env' do
      it 'runs the command with the environment variables set' do
        shell.should_receive(:run).with('. /tmp/deployments-repo/fake-a1/bosh_environment && bosh aws create')
        account.run_with_env('bosh aws create')
      end
    end
  end
end
