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
    let(:repository_path) { '/tmp/repo/' }

    let(:cli) { instance_double('Bosh::Dev::BoshCliSession').as_null_object }
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
      let(:stemcell_archive) { instance_double('Bosh::Stemcell::Archive', name: 'fake_stemcell', version: '1') }

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

      context 'when the stemcell is not on the microbosh director but is on bosh director' do

        it 'uploads the stemcell to the microbosh director' do
          micro_director_client.stub(:has_stemcell?).with('fake_stemcell', '1').and_return false
          bosh_director_client.stub(:has_stemcell?).with('fake_stemcell', '1').and_return true

          cli.should_receive(:run_bosh).with("upload stemcell #{stemcell_path}", debug_on_fail: true).once

          deployer.deploy
        end
      end

      context 'when the stemcell is already on the microbosh director but not on the bosh director' do
        it 'does not upload the stemcell to the microbosh' do
          micro_director_client.should_receive(:has_stemcell?).with('fake_stemcell', '1').and_return true
          bosh_director_client.should_receive(:has_stemcell?).with('fake_stemcell', '1').and_return false

          cli.should_receive(:run_bosh).with("upload stemcell #{stemcell_path}", debug_on_fail: true).once

          deployer.deploy
        end

      end

      context 'when the stemcell is on both the microbosh director and the bosh director' do
        it 'does not upload any stemcells' do
          micro_director_client.should_receive(:has_stemcell?).with('fake_stemcell', '1').and_return(true)

          bosh_director_client.should_receive(:has_stemcell?).with('fake_stemcell', '1').and_return(true)
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

