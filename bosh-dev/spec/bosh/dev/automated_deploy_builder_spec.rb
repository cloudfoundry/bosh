require 'spec_helper'
require 'bosh/dev/automated_deploy_builder'

module Bosh::Dev
  describe AutomatedDeployBuilder do
    describe '#build' do
      it 'builds automated deploy' do
        stemcell = instance_double(
          'Bosh::Stemcell::Stemcell',
          infrastructure: double(:infrastructure, name: 'aws'),
          version: 'fake-number',
        )

        deployments_repository = instance_double('Bosh::Dev::DeploymentsRepository')
        expect(Bosh::Dev::DeploymentsRepository).to receive(:new).with(ENV, logger, kind_of(Hash)).and_return(deployments_repository)

        deployment_account = instance_double('Bosh::Dev::Aws::DeploymentAccount')
        expect(Bosh::Dev::Aws::DeploymentAccount).to receive(:new).with(
          'fake-environment-name',
          'fake-deployment-name',
          deployments_repository,
        ).and_return(deployment_account)

        artifacts_downloader = instance_double('Bosh::Dev::ArtifactsDownloader')
        expect(Bosh::Dev::ArtifactsDownloader).to receive(:new).with(
          be_an_instance_of(Bosh::Dev::DownloadAdapter),
          be_a_kind_of(Logging::Logger),
        ).and_return(artifacts_downloader)

        s3_gem_bosh_cmd = instance_double('Bosh::Dev::S3GemBoshCmd')
        expect(Bosh::Dev::S3GemBoshCmd).to receive(:new).
          with('fake-number', be_a_kind_of(Logging::Logger)).
          and_return(s3_gem_bosh_cmd)

        bosh_cli_session = instance_double('Bosh::Dev::BoshCliSession')
        expect(Bosh::Dev::BoshCliSession).to receive(:new).
          with(s3_gem_bosh_cmd).
          and_return(bosh_cli_session)

        automated_deploy = instance_double('Bosh::Dev::AutomatedDeploy')
        expect(Bosh::Dev::AutomatedDeploy).to receive(:new).with(
          stemcell,
          deployment_account,
          artifacts_downloader,
          bosh_cli_session,
        ).and_return(automated_deploy)

        builder = described_class.new(
          stemcell,
          'fake-environment-name',
          'fake-deployment-name',
        )

        expect(builder.build).to eq(automated_deploy)
      end
    end
  end
end
