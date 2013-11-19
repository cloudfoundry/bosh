require 'spec_helper'
require 'bosh/dev/automated_deployer'
require 'bosh/dev/artifacts_downloader'
require 'bosh/dev/deployments_repository'
require 'bosh/dev/aws/deployment_account'

module Bosh::Dev
  describe AutomatedDeployer do
    describe '#deploy' do
      subject(:deployer) do
        described_class.new(
          micro_target,
          bosh_target,
          build_number,
          deployment_account,
          artifacts_downloader,
          deployments_repository
        )
      end

      let(:micro_target) { 'https://micro.target.example.com:25555' }
      let(:bosh_target) { 'https://bosh.target.example.com:25555' }
      let(:build_number) { '123' }

      let(:deployment_account) do
        instance_double(
          'Bosh::Dev::Aws::DeploymentAccount',
          manifest_path: '/path/to/manifest.yml',
          bosh_user: 'fake-username',
          bosh_password: 'fake-password',
        )
      end

      let(:artifacts_downloader) { instance_double('Bosh::Dev::ArtifactsDownloader') }

      let(:deployments_repository) { instance_double('Bosh::Dev::DeploymentsRepository') }

      before { Bosh::Stemcell::Archive.stub(:new).with('/tmp/stemcell.tgz').and_return(stemcell_archive) }
      let(:stemcell_archive) { instance_double('Bosh::Stemcell::Archive', name: 'fake_stemcell', version: '1', path: stemcell_path) }

      let(:stemcell_path) { '/tmp/stemcell.tgz' }
      let(:release_path) { '/tmp/release.tgz' }
      let(:repository_path) { '/tmp/repo' }

      before do
        Bosh::Dev::DirectorClient.stub(:new).with(
          uri: micro_target,
          username: 'fake-username',
          password: 'fake-password',
        ).and_return(micro_director_client)
      end

      let(:micro_director_client) do
        instance_double('Bosh::Dev::DirectorClient', upload_stemcell: nil, upload_release: nil, deploy: nil)
      end

      before do
        Bosh::Dev::DirectorClient.stub(:new).with(
          uri: bosh_target,
          username: 'fake-username',
          password: 'fake-password',
        ).and_return(bosh_director_client)
      end

      let(:bosh_director_client) do
        instance_double('Bosh::Dev::DirectorClient', upload_stemcell: nil, upload_release: nil, deploy: nil)
      end

      before do
        artifacts_downloader.stub(:download_release).with(build_number).and_return(release_path)
        artifacts_downloader.stub(:download_stemcell).with(build_number).and_return(stemcell_path)

        Bosh::Stemcell::Archive.stub(:new).with('/tmp/stemcell.tgz').and_return(stemcell_archive)
      end

      it 'follows the normal deploy procedure' do
        Bosh::Stemcell::Archive.should_receive(:new).with('/tmp/stemcell.tgz').and_return(stemcell_archive)
        micro_director_client.should_receive(:upload_stemcell).with(stemcell_archive)
        micro_director_client.should_receive(:upload_release).with('/tmp/release.tgz')
        micro_director_client.should_receive(:deploy).with('/path/to/manifest.yml')
        bosh_director_client.should_receive(:upload_stemcell).with(stemcell_archive)

        deployer.deploy
      end

      describe '#migrate' do
        it 'runs AWS migrations' do
          deployment_account.should_receive(:run_with_env).with('bosh aws create --trace')
          deployments_repository.should_receive(:push)
          deployer.migrate
        end

      end
    end
  end
end
