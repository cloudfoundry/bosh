require 'spec_helper'
require 'bosh/dev/bat/artifacts'
require 'bosh/dev/vsphere/runner_builder'

module Bosh::Dev::VSphere
  describe RunnerBuilder do
    describe '#build' do
      it 'returns vsphere runner with injected env and proper director address' do
        artifacts = instance_double(
          'Bosh::Dev::Bat::Artifacts',
          stemcell_path: 'stemcell-path',
        )

        director_address = instance_double('Bosh::Dev::Bat::DirectorAddress')
        expect(Bosh::Dev::Bat::DirectorAddress)
          .to receive(:from_env)
          .with(ENV, 'BOSH_VSPHERE_MICROBOSH_IP')
          .and_return(director_address)

        bosh_cli_session = instance_double('Bosh::Dev::BoshCliSession')
        expect(Bosh::Dev::BoshCliSession)
          .to receive(:new)
          .and_return(bosh_cli_session)

        stemcell_archive = instance_double(
          'Bosh::Stemcell::Archive',
          version: 'stemcell-archive-version',
        )
        expect(Bosh::Stemcell::Archive)
          .to receive(:new)
          .with('stemcell-path')
          .and_return(stemcell_archive)

        microbosh_deployment_manifest = instance_double('Bosh::Dev::VSphere::MicroBoshDeploymentManifest')
        expect(Bosh::Dev::VSphere::MicroBoshDeploymentManifest)
          .to receive(:new)
          .with(ENV, 'net-type')
          .and_return(microbosh_deployment_manifest)

        microbosh_deployment_cleaner = instance_double('Bosh::Dev::VSphere::MicroBoshDeploymentCleaner')
        expect(Bosh::Dev::VSphere::MicroBoshDeploymentCleaner)
          .to receive(:new)
          .with(microbosh_deployment_manifest)
          .and_return(microbosh_deployment_cleaner)

        director_uuid = instance_double('Bosh::Dev::Bat::DirectorUuid')
        expect(Bosh::Dev::Bat::DirectorUuid)
          .to receive(:new)
          .with(bosh_cli_session)
          .and_return(director_uuid)

        ENV['BOSH_VSPHERE_BAT_DEPLOYMENT_SPEC'] = '/fake/config/path.yml'
        bat_deployment_manifest = instance_double('Bosh::Dev::Bat::DeploymentManifest')
        expect(Bosh::Dev::Bat::DeploymentManifest)
          .to receive(:load_from_file)
          .with('/fake/config/path.yml')
          .and_return(bat_deployment_manifest)

        expect(bat_deployment_manifest).to receive(:net_type=).with('net-type')
        expect(bat_deployment_manifest).to receive(:director_uuid=).with(director_uuid)
        expect(bat_deployment_manifest).to receive(:stemcell=).with(stemcell_archive)

        runner = instance_double('Bosh::Dev::Bat::Runner')
        expect(Bosh::Dev::Bat::Runner).to receive(:new).with(
          ENV,
          artifacts,
          director_address,
          bosh_cli_session,
          stemcell_archive,
          microbosh_deployment_manifest,
          bat_deployment_manifest,
          microbosh_deployment_cleaner,
          be_a_kind_of(Logging::Logger),
        ).and_return(runner)

        expect(subject.build(artifacts, 'net-type')).to eq(runner)
      end
    end
  end
end
