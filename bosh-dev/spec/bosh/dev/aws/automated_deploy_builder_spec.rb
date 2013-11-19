require 'spec_helper'
require 'bosh/dev/aws/automated_deploy_builder'

module Bosh::Dev::Aws
  describe AutomatedDeployBuilder do
    describe '#build' do
      it 'builds runner' do
        deployments_repository = instance_double('Bosh::Dev::DeploymentsRepository')
        Bosh::Dev::DeploymentsRepository
          .should_receive(:new)
          .with(ENV, path_root: '/tmp')
          .and_return(deployments_repository)

        deployment_account = instance_double('Bosh::Dev::Aws::DeploymentAccount')
        Bosh::Dev::Aws::DeploymentAccount.should_receive(:new).with(
          'fake-environment',
          deployments_repository,
        ).and_return(deployment_account)

        artifacts_downloader = instance_double('Bosh::Dev::ArtifactsDownloader')
        Bosh::Dev::ArtifactsDownloader.should_receive(:new).with(no_args).and_return(artifacts_downloader)

        automated_deployer = instance_double('Bosh::Dev::AutomatedDeployer')
        Bosh::Dev::AutomatedDeployer.should_receive(:new).with(
          'fake-micro-target',
          'fake-bosh-target',
          'fake-build-number',
          deployment_account,
          artifacts_downloader,
        ).and_return(automated_deployer)

        expect(subject.build(
          'fake-micro-target',
          'fake-bosh-target',
          'fake-build-number',
          'fake-environment',
        )).to eq(automated_deployer)
      end
    end
  end
end
