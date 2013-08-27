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
    let(:micro_director_client) { instance_double('Bosh::Dev::DirectorClient') }
    let(:bosh_director_client) { instance_double('Bosh::Dev::DirectorClient') }

    subject(:deployer) do
      AutomatedDeployer.new(micro_target: micro_target,
                            bosh_target: bosh_target,
                            build_number: build_number,
                            environment: environment,
                            shell: shell,
                            deployments_repository: deployments_repository,
                            artifacts_downloader: artifacts_downloader,
                            cli: cli,
                            micro_director_client: micro_director_client,
                            bosh_director_client: bosh_director_client)
    end

    before do
      Bosh::Stemcell::Archive.stub(:new).with('/tmp/stemcell.tgz').and_return(stemcell_archive)
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
        bosh_should_be_called_with 'target micro.target.example.com'
        bosh_should_be_called_with 'login user password'
        bosh_should_be_called_with "deployment #{repository_path}/#{environment}/deployments/bosh/bosh.yml"
        Bosh::Stemcell::Archive.should_receive(:new).with('/tmp/stemcell.tgz').and_return(stemcell_archive)
        micro_director_client.should_receive(:has_stemcell?).with('fake_stemcell', '1').and_return false
        bosh_should_be_called_with 'upload stemcell /tmp/stemcell.tgz', debug_on_fail: true
        bosh_should_be_called_with 'upload release /tmp/release.tgz --rebase', debug_on_fail: true
        bosh_should_be_called_with 'deploy', debug_on_fail: true

        bosh_should_be_called_with 'target bosh.target.example.com'
        bosh_should_be_called_with 'login user password'
        bosh_director_client.should_receive(:has_stemcell?).with('fake_stemcell', '1').and_return false
        bosh_should_be_called_with 'upload stemcell /tmp/stemcell.tgz', debug_on_fail: true

        deployer.deploy
      end

      # Yes yes we are stubbing private methods, horrible
      # but this gives us better isolation in tests
      # also the bigger context is AutomatedDeployer#deploy is called in a Rake Task
      # and we do want a minimal amount of logic in there :-/
      context 'uploading stemcell to the microbosh' do
        before { deployer.stub(:upload_stemcell_to_bosh_director) }

        it 'is done when it is not on the microbosh director' do
          micro_director_client.stub(:has_stemcell?).with('fake_stemcell', '1').and_return false
          cli.should_receive(:run_bosh).with("upload stemcell #{stemcell_path}", debug_on_fail: true).once

          deployer.deploy
        end

        it 'is not done when it is on the microbosh director' do
          micro_director_client.stub(:has_stemcell?).with('fake_stemcell', '1').and_return true
          cli.should_not_receive(:run_bosh).with("upload stemcell #{stemcell_path}", debug_on_fail: true)

          deployer.deploy
        end
      end

      context 'uploading stemcell to bosh director' do
        before { deployer.stub(:deploy_to_micro) }

        it 'is done when it is not on the bosh director' do
          bosh_director_client.stub(:has_stemcell?).with('fake_stemcell', '1').and_return false

          cli.should_receive(:run_bosh).with("upload stemcell #{stemcell_path}", debug_on_fail: true).ordered.once

          deployer.deploy
        end

        it 'is not done when it is on the bosh director' do
          bosh_director_client.stub(:has_stemcell?).with('fake_stemcell', '1').and_return true

          cli.should_not_receive(:run_bosh).with("upload stemcell #{stemcell_path}", debug_on_fail: true)

          deployer.deploy
        end
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
