require 'spec_helper'
require 'bosh/dev/automated_deploy_builder'

module Bosh::Dev
  describe AutomatedDeployBuilder do
    describe '.for_rake_args' do
      it 'returns automated deployer builder for rake arguments' do
        rake_args = Struct.new(
          :build_number,
          :infrastructure_name,
          :operating_system_name,
          :operating_system_version,
          :agent_name,
          :environment_name,
          :deployment_name,
        ).new(
          'fake-build-number',
          'fake-infrastructure-name',
          'fake-operating-system-name',
          'fake-operating-system-version',
          'fake-agent-name',
          'fake-environment-name',
          'fake-deployment-name',
        )

        build_target = instance_double('Bosh::Dev::BuildTarget')
        expect(Bosh::Dev::BuildTarget).to receive(:from_names).with(
          'fake-build-number',
          'fake-infrastructure-name',
          'fake-operating-system-name',
          'fake-operating-system-version',
          'fake-agent-name',
        ).and_return(build_target)

        builder = instance_double('Bosh::Dev::AutomatedDeployBuilder')
        expect(described_class).to receive(:new).with(
          build_target,
          'fake-environment-name',
          'fake-deployment-name',
        ).and_return(builder)

        expect(described_class.for_rake_args(rake_args)).to eq(builder)
      end
    end

    describe '#build' do
      it 'builds automated deploy' do
        build_target = instance_double('Bosh::Dev::BuildTarget', infrastructure_name: 'aws')

        deployments_repository = instance_double('Bosh::Dev::DeploymentsRepository')
        expect(Bosh::Dev::DeploymentsRepository).to receive(:new).with(ENV).and_return(deployments_repository)

        deployment_account = instance_double('Bosh::Dev::Aws::DeploymentAccount')
        expect(Bosh::Dev::Aws::DeploymentAccount).to receive(:new).with(
          'fake-environment-name',
          'fake-deployment-name',
          deployments_repository,
        ).and_return(deployment_account)

        artifacts_downloader = instance_double('Bosh::Dev::ArtifactsDownloader')
        expect(Bosh::Dev::ArtifactsDownloader).to receive(:new).with(
          be_an_instance_of(Bosh::Dev::DownloadAdapter),
          be_an_instance_of(::Logger),
        ).and_return(artifacts_downloader)

        automated_deploy = instance_double('Bosh::Dev::AutomatedDeploy')
        expect(Bosh::Dev::AutomatedDeploy).to receive(:new).with(
          build_target,
          deployment_account,
          artifacts_downloader,
        ).and_return(automated_deploy)

        builder = described_class.new(
          build_target,
          'fake-environment-name',
          'fake-deployment-name',
        )

        expect(builder.build).to eq(automated_deploy)
      end
    end
  end
end
