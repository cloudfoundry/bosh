require 'spec_helper'
require 'bosh/dev/build_target'
require 'bosh/dev/vsphere/automated_deploy_builder'

module Bosh::Dev::VSphere
  describe AutomatedDeployBuilder do
    describe '#build' do
      it 'builds runner' do
        build_target = instance_double('Bosh::Dev::BuildTarget')

        deployments_repository = instance_double('Bosh::Dev::DeploymentsRepository')
        Bosh::Dev::DeploymentsRepository
          .should_receive(:new)
          .with(ENV, path_root: '/tmp')
          .and_return(deployments_repository)

        deployment_account = instance_double('Bosh::Dev::VSphere::DeploymentAccount')
        Bosh::Dev::VSphere::DeploymentAccount
          .should_receive(:new).with(
            'fake-environment-name',
            'fake-deployment-name',
            deployments_repository,
          ).and_return(deployment_account)

        artifacts_downloader = instance_double('Bosh::Dev::ArtifactsDownloader')
        Bosh::Dev::ArtifactsDownloader
          .should_receive(:new)
          .with(be_an_instance_of(Bosh::Dev::DownloadAdapter), be_an_instance_of(Logger))
          .and_return(artifacts_downloader)

        automated_deploy = instance_double('Bosh::Dev::AutomatedDeploy')
        Bosh::Dev::AutomatedDeploy.should_receive(:new).with(
          build_target,
          'fake-bosh-target',
          deployment_account,
          artifacts_downloader,
        ).and_return(automated_deploy)

        expect(subject.build(
          build_target,
          'fake-bosh-target',
          'fake-environment-name',
          'fake-deployment-name',
        )).to eq(automated_deploy)
      end
    end
  end
end
