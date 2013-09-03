require 'spec_helper'
require 'bosh/dev/aws/deployment_account'
require 'bosh/stemcell/archive'

module Bosh::Dev::Aws
  describe DeploymentAccount do
    let(:deployment_name) { 'fake-a1' }
    let(:shell) { instance_double('Bosh::Core::Shell') }
    let(:repository_path) { '/tmp/deployments-repo' }
    let(:deployments_repository) { instance_double('Bosh::Dev::Aws::DeploymentsRepository', path: repository_path, clone_or_update!: nil) }

    subject(:account) do
      DeploymentAccount.new(deployment_name)
    end

    before do
      Bosh::Core::Shell.stub(new: shell)
      DeploymentsRepository.stub(:new).with(path_root: '/tmp').and_return(deployments_repository)

      shell.stub(:run).with('. /tmp/deployments-repo/fake-a1/bosh_environment && echo $BOSH_USER').and_return("fake-username\n")
      shell.stub(:run).with('. /tmp/deployments-repo/fake-a1/bosh_environment && echo $BOSH_PASSWORD').and_return("fake-password\n")
    end

    its(:manifest_path) { should eq("#{repository_path}/#{deployment_name}/deployments/bosh/bosh.yml") }
    its(:bosh_user) { should eq('fake-username') }
    its(:bosh_password) { should eq('fake-password') }

    it "clones a deployment repository for the deployment's manifest & bosh_environment" do
      deployments_repository.should_receive(:clone_or_update!)

      account
    end
  end
end
