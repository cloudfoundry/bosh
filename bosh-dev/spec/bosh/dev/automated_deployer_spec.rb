require 'spec_helper'
require 'bosh/dev/build'
require 'bosh/dev/automated_deployer'
require 'bosh/dev/artifacts_downloader'
require 'bosh/dev/aws/deployment_account'

module Bosh::Dev
  describe AutomatedDeployer do
    describe '.for_rake_args' do
      it 'returns automated deployer builder for rake arguments' do
        builder = instance_double('Bosh::Dev::Aws::AutomatedDeployBuilder')
        described_class
          .should_receive(:builder_for_infrastructure_name)
          .with('fake-infrastructure-name')
          .and_return(builder)

        infrastructure = instance_double('Bosh::Stemcell::Infrastructure')
        Bosh::Stemcell::Infrastructure
          .should_receive(:for)
          .with('fake-infrastructure-name')
          .and_return(infrastructure)

        operating_system = instance_double('Bosh::Stemcell::OperatingSystem')
        Bosh::Stemcell::OperatingSystem
          .should_receive(:for)
          .with('fake-operating-system-name')
          .and_return(operating_system)

        deployer = instance_double('Bosh::Dev::AutomatedDeployer')
        builder.should_receive(:build).with(
          'fake-build-number',
          infrastructure,
          operating_system,
          'fake-micro-target',
          'fake-bosh-target',
          'fake-environment-name',
          'fake-deployment-name',
        ).and_return(deployer)

        rake_args = Struct.new(
          :build_number,
          :infrastructure_name,
          :operating_system_name,
          :micro_target,
          :bosh_target,
          :environment_name,
          :deployment_name,
        ).new(
          'fake-build-number',
          'fake-infrastructure-name',
          'fake-operating-system-name',
          'fake-micro-target',
          'fake-bosh-target',
          'fake-environment-name',
          'fake-deployment-name',
        )

        expect(described_class.for_rake_args(rake_args)).to eq(deployer)
      end
    end

    describe '.builder_for_infrastructure_name' do
      context 'when infrastructure name is aws' do
        it 'returns aws builder' do
          expect(described_class.builder_for_infrastructure_name('aws'))
            .to be_an_instance_of(Bosh::Dev::Aws::AutomatedDeployBuilder)
        end
      end

      context 'when infrastructure name is vsphere' do
        it 'returns vsphere builder' do
          expect(described_class.builder_for_infrastructure_name('vsphere'))
            .to be_an_instance_of(Bosh::Dev::VSphere::AutomatedDeployBuilder)
        end
      end
    end

    describe '#deploy' do
      subject(:deployer) do
        described_class.new(
          'fake-build-number',
          infrastructure,
          operating_system,
          micro_target,
          bosh_target,
          deployment_account,
          artifacts_downloader,
        )
      end

      let(:infrastructure) do
        instance_double(
          'Bosh::Stemcell::Infrastructure',
          name: 'fake-infrastructure-name',
          hypervisor: 'fake-infrastructure-hypervisor',
        )
      end

      let(:operating_system) do
        instance_double(
          'Bosh::Stemcell::OperatingSystem',
          name: 'fake-os-name',
        )
      end

      let(:micro_target) { 'https://micro.target.example.com:25555' }
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

      it 'prepare deployment account and then follows the normal deploy procedure' do
        expect(deployment_account).to receive(:prepare).with(no_args)

        artifacts_downloader
          .should_receive(:download_release)
          .with('fake-build-number')
          .and_return('/tmp/release.tgz')

        artifacts_downloader
          .should_receive(:download_stemcell)
          .with('fake-build-number', infrastructure, operating_system, false, Dir.pwd)
          .and_return('/tmp/stemcell.tgz')

        stemcell_archive = instance_double('Bosh::Stemcell::Archive')
        Bosh::Stemcell::Archive.should_receive(:new).with('/tmp/stemcell.tgz').and_return(stemcell_archive)

        micro_director_client.should_receive(:upload_stemcell).with(stemcell_archive)
        micro_director_client.should_receive(:upload_release).with('/tmp/release.tgz')
        micro_director_client.should_receive(:deploy).with('/path/to/manifest.yml')
        bosh_director_client.should_receive(:upload_stemcell).with(stemcell_archive)

        deployer.deploy
      end
    end
  end
end
