require 'spec_helper'
require 'bosh/dev/build_target'
require 'bosh/dev/artifacts_downloader'
require 'bosh/dev/aws/deployment_account'
require 'bosh/dev/automated_deploy'

module Bosh::Dev
  describe AutomatedDeploy do
    describe '#deploy' do
      subject(:deployer) do
        described_class.new(
          build_target,
          deployment_account,
          artifacts_downloader,
        )
      end

      let(:build_target) do
        instance_double(
          'Bosh::Dev::BuildTarget',
          build_number: 'fake-build-number',
        )
      end

      let(:bosh_target) { 'https://bosh.target.example.com:25555' }

      let(:deployment_account) do
        instance_double(
          'Bosh::Dev::Aws::DeploymentAccount',
          manifest_path: '/path/to/manifest.yml',
          bosh_user: 'fake-username',
          bosh_password: 'fake-password',
        )
      end

      let(:artifacts_downloader) { instance_double('Bosh::Dev::ArtifactsDownloader') }

      before do
        Bosh::Dev::DirectorClient.stub(:new).with(
          uri: bosh_target,
          username: 'fake-username',
          password: 'fake-password',
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

      it 'prepare deployment account and then follows the normal deploy procedure and then cleans up old resources' do
        expect(deployment_account).to receive(:prepare).with(no_args).ordered

        artifacts_downloader.
          should_receive(:download_stemcell).
          with(build_target, Dir.pwd).
          ordered.
          and_return('/tmp/stemcell.tgz')

        stemcell_archive = instance_double('Bosh::Stemcell::Archive')
        Bosh::Stemcell::Archive.should_receive(:new).with('/tmp/stemcell.tgz').and_return(stemcell_archive)

        director_client.should_receive(:upload_stemcell).with(stemcell_archive).ordered

        artifacts_downloader.
          should_receive(:download_release).
          with('fake-build-number', Dir.pwd).
          ordered.
          and_return('/tmp/release.tgz')

        director_client.should_receive(:upload_release).with('/tmp/release.tgz').ordered

        director_client.should_receive(:deploy).with('/path/to/manifest.yml').ordered

        director_client.should_receive(:clean_up).with(no_args).ordered

        deployer.deploy(bosh_target)
      end
    end

    describe '#deploy_micro' do
      subject(:deployer) do
        described_class.new(
          build_target,
          deployment_account,
          artifacts_downloader,
        )
      end

      let(:build_target) do
        instance_double(
          'Bosh::Dev::BuildTarget',
          build_number: 'fake-build-number',
        )
      end

      let(:deployment_account) do
        instance_double(
          'Bosh::Dev::Aws::DeploymentAccount',
          manifest_path: '/path/to/manifest.yml',
          bosh_user: 'fake-username',
          bosh_password: 'fake-password',
        )
      end

      let(:artifacts_downloader) { instance_double('Bosh::Dev::ArtifactsDownloader') }

      before { allow(Bosh::Dev::MicroClient).to receive(:new).with(no_args).and_return(micro_client) }
      let(:micro_client) { instance_double('Bosh::Dev::MicroClient', deploy: nil) }

      it 'prepare deployment account and then follows the normal micro bosh deploy procedure' do
        expect(deployment_account).to receive(:prepare).with(no_args).ordered

        artifacts_downloader
          .should_receive(:download_stemcell)
          .with(build_target, Dir.pwd)
          .and_return('/tmp/stemcell.tgz')

        stemcell_archive = instance_double('Bosh::Stemcell::Archive')
        Bosh::Stemcell::Archive.should_receive(:new).with('/tmp/stemcell.tgz').and_return(stemcell_archive)

        micro_client.should_receive(:deploy).with('/path/to/manifest.yml', stemcell_archive).ordered

        expect(deployment_account).to receive(:save).with(no_args).ordered

        deployer.deploy_micro
      end
    end
  end
end
