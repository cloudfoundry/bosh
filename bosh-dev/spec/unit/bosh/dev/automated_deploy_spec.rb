require 'spec_helper'
require 'bosh/dev/artifacts_downloader'
require 'bosh/dev/aws/deployment_account'
require 'bosh/dev/automated_deploy'

module Bosh::Dev
  describe AutomatedDeploy do
    let(:stemcell) do
      instance_double(
        'Bosh::Stemcell::Stemcell',
        infrastructure: double(:infrastructure, name: 'aws'),
        version: 'fake-build-number',
      )
    end

    describe '#deploy' do
      subject(:deployer) do
        described_class.new(
          stemcell,
          deployment_account,
          artifacts_downloader,
          bosh_cli_session,
        )
      end

      let(:bosh_target) { 'https://bosh.target.example.com:25555' }

      let(:deployment_account) do
        instance_double('Bosh::Dev::Aws::DeploymentAccount', {
          manifest_path: '/path/to/manifest.yml',
          bosh_user: 'fake-username',
          bosh_password: 'fake-password',
        })
      end

      let(:artifacts_downloader) { instance_double('Bosh::Dev::ArtifactsDownloader') }

      let(:bosh_cli_session) { instance_double('Bosh::Dev::BoshCliSession') }

      before do
        allow(Bosh::Dev::DirectorClient).to receive(:new).with(
          bosh_target,
          'fake-username',
          'fake-password',
          bosh_cli_session,
        ).and_return(director_client)
      end

      let(:director_client) do
        instance_double('Bosh::Dev::DirectorClient', {
          upload_stemcell: nil,
          upload_release: nil,
          deploy: nil,
          clean_up: nil,
        })
      end

      it 'prepare deployment account, follows the normal deploy procedure and then cleans up old resources' do
        expect(deployment_account).to receive(:prepare).with(no_args).ordered

        expect(artifacts_downloader).to receive(:download_stemcell).
          with(stemcell, Dir.pwd).ordered.
          and_return('/tmp/stemcell.tgz')

        stemcell_archive = instance_double('Bosh::Stemcell::Archive')
        expect(Bosh::Stemcell::Archive).to receive(:new).
          with('/tmp/stemcell.tgz').
          and_return(stemcell_archive)

        expect(director_client).to receive(:upload_stemcell).with(stemcell_archive).ordered

        expect(artifacts_downloader).to receive(:download_release).
          with('fake-build-number', Dir.pwd).ordered.
          and_return('/tmp/release.tgz')

        expect(director_client).to receive(:upload_release).with('/tmp/release.tgz').ordered

        expect(director_client).to receive(:deploy).with('/path/to/manifest.yml').ordered

        expect(director_client).to receive(:clean_up).with(no_args).ordered

        expect(bosh_cli_session).to receive(:close).with(no_args).ordered

        deployer.deploy(bosh_target)
      end
    end

    describe '#deploy_micro' do
      subject(:deployer) do
        described_class.new(
          stemcell,
          deployment_account,
          artifacts_downloader,
          bosh_cli_session,
        )
      end

      let(:deployment_account) do
        instance_double('Bosh::Dev::Aws::DeploymentAccount', {
          manifest_path: '/path/to/manifest.yml',
          bosh_user: 'fake-username',
          bosh_password: 'fake-password',
        })
      end

      let(:artifacts_downloader) { instance_double('Bosh::Dev::ArtifactsDownloader') }

      let(:bosh_cli_session) { instance_double('Bosh::Dev::BoshCliSession') }

      before do
        allow(Bosh::Dev::MicroClient).to receive(:new).
          with(bosh_cli_session).
          and_return(micro_client)
      end

      let(:micro_client) { instance_double('Bosh::Dev::MicroClient', deploy: nil) }

      it 'prepare deployment account and then follows the normal micro bosh deploy procedure' do
        expect(deployment_account).to receive(:prepare).with(no_args).ordered

        expect(artifacts_downloader).to receive(:download_stemcell)
          .with(stemcell, Dir.pwd)
          .and_return('/tmp/stemcell.tgz')

        stemcell_archive = instance_double('Bosh::Stemcell::Archive')
        expect(Bosh::Stemcell::Archive).to receive(:new).
          with('/tmp/stemcell.tgz').
          and_return(stemcell_archive)

        expect(micro_client).to receive(:deploy).
          with('/path/to/manifest.yml', stemcell_archive).ordered

        expect(deployment_account).to receive(:save).with(no_args).ordered

        expect(bosh_cli_session).to receive(:close).with(no_args)

        deployer.deploy_micro
      end
    end
  end
end
