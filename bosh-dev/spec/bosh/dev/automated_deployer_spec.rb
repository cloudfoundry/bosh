require 'spec_helper'
require 'bosh/dev/automated_deployer'
require 'bosh/stemcell/archive'

module Bosh::Dev
  describe AutomatedDeployer do
    let(:micro_target) { 'micro.target.example.com' }
    let(:bosh_target) { 'bosh.target.example.com' }
    let(:username) { 'user' }
    let(:password) { 'password' }

    let(:environment) { 'test_env' }
    let(:stemcell_path) { '/tmp/stemcell.tgz' }
    let(:release_path) { '/tmp/release.tgz' }
    let(:repository_path) { '/tmp/repo' }

    let(:cli) { instance_double('Bosh::Dev::BoshCliSession', run_bosh: nil) }
    let(:deployments_repository) { instance_double('Bosh::Dev::Aws::DeploymentsRepository', path: repository_path, clone_or_update!: nil) }
    let(:build_number) { '123' }
    let(:artifacts_downloader) { instance_double('Bosh::Dev::ArtifactsDownloader') }

    let(:shell) { instance_double('Bosh::Core::Shell') }
    let(:micro_director_client) { instance_double('Bosh::Dev::DirectorClient', upload_stemcell: nil) }
    let(:bosh_director_client) { instance_double('Bosh::Dev::DirectorClient', upload_stemcell: nil) }

    subject(:deployer) do
      AutomatedDeployer.new(
        micro_target: micro_target,
        bosh_target: bosh_target,
        build_number: build_number,
        environment: environment,
        shell: shell,
        deployments_repository: deployments_repository,
        artifacts_downloader: artifacts_downloader,
        cli: cli,
      )
    end

    before do
      Bosh::Stemcell::Archive.stub(:new).with('/tmp/stemcell.tgz').and_return(stemcell_archive)
      Bosh::Dev::DirectorClient.stub(:new).with(uri: micro_target, username: username, password: password, cli: cli).and_return(micro_director_client)
      Bosh::Dev::DirectorClient.stub(:new).with(uri: bosh_target, username: username, password: password, cli: cli).and_return(bosh_director_client)
    end

    describe '#deploy' do
      let(:stemcell_archive) { instance_double('Bosh::Stemcell::Archive', name: 'fake_stemcell', version: '1', path: stemcell_path) }

      before do
        artifacts_downloader.stub(:download_release).with(build_number).and_return(release_path)
        artifacts_downloader.stub(:download_stemcell).with(build_number).and_return(stemcell_path)

        shell.stub(:run).with('. /tmp/repo/test_env/bosh_environment && echo $BOSH_USER').and_return("#{username}\n")
        shell.stub(:run).with('. /tmp/repo/test_env/bosh_environment && echo $BOSH_PASSWORD').and_return("#{password}\n")

        Bosh::Stemcell::Archive.stub(:new).with('/tmp/stemcell.tgz').and_return(stemcell_archive)
      end

      def bosh_should_be_called_with(*args)
        cli.should_receive(:run_bosh).with(*args).ordered
      end

      it 'follows the normal deploy procedure' do
        Bosh::Stemcell::Archive.should_receive(:new).with('/tmp/stemcell.tgz').and_return(stemcell_archive)
        micro_director_client.should_receive(:upload_stemcell).with(stemcell_archive)

        bosh_should_be_called_with 'upload release /tmp/release.tgz --rebase', debug_on_fail: true
        bosh_should_be_called_with "deployment #{repository_path}/#{environment}/deployments/bosh/bosh.yml"
        bosh_should_be_called_with 'deploy', debug_on_fail: true

        bosh_director_client.should_receive(:upload_stemcell).with(stemcell_archive)

        deployer.deploy
      end

      it 'clones a deployment repository' do
        micro_director_client.stub(has_stemcell?: false)
        bosh_director_client.stub(has_stemcell?: false)

        deployments_repository.should_receive(:clone_or_update!)

        deployer.deploy
      end
    end
  end
end
