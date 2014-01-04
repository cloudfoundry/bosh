require 'spec_helper'
require 'bosh/dev/deployments_repository'
require 'bosh/dev/aws/deployment_account'

module Bosh::Dev::Aws
  describe DeploymentAccount do
    subject(:account) do
      described_class.new(
        'fake-env',
        'fake-deployment-name',
        deployments_repository,
      )
    end

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
      before { shell.stub(:run).with('. /tmp/deployments-repo/fake-env/bosh_environment && echo $BOSH_USER').and_return("fake-username\n") }
      before { shell.stub(:run).with('. /tmp/deployments-repo/fake-env/bosh_environment && echo $BOSH_PASSWORD').and_return("fake-password\n") }

      its(:manifest_path) { should eq('/tmp/deployments-repo/fake-env/deployments/fake-deployment-name/manifest.yml') }
      its(:bosh_user)     { should eq('fake-username') }
      its(:bosh_password) { should eq('fake-password') }

      it 'clones a deployment repository for the deployment\'s manifest & bosh_environment' do
        deployments_repository.should_receive(:clone_or_update!)
        account
      end
    end

    describe '#prepare' do
      it 'runs AWS migrations and pushes changes to deployments repo' do
        shell.should_receive(:run).with('. /tmp/deployments-repo/fake-env/bosh_environment && bosh aws create --trace')
        deployments_repository.should_receive(:push)
        account.prepare
      end
    end
  end
end
