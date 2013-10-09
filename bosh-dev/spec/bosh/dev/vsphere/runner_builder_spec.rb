require 'spec_helper'
require 'bosh/dev/bat_helper'
require 'bosh/dev/vsphere/runner_builder'

module Bosh::Dev::VSphere
  describe RunnerBuilder do
    describe '#build' do
      it 'returns vsphere runner with injected env and proper director address' do
        bat_helper = instance_double(
          'Bosh::Dev::BatHelper',
          bosh_stemcell_path: 'stemcell-path',
        )

        director_address = instance_double('Bosh::Dev::Bat::DirectorAddress')
        Bosh::Dev::Bat::DirectorAddress
          .should_receive(:from_env)
          .with(ENV, 'BOSH_VSPHERE_MICROBOSH_IP')
          .and_return(director_address)

        bosh_cli_session = instance_double('Bosh::Dev::BoshCliSession')
        Bosh::Dev::BoshCliSession
          .should_receive(:new)
          .and_return(bosh_cli_session)

        stemcell_archive = instance_double(
          'Bosh::Stemcell::Archive',
          version: 'stemcell-archive-version',
        )
        Bosh::Stemcell::Archive
          .should_receive(:new)
          .with('stemcell-path')
          .and_return(stemcell_archive)

        microbosh_deployment_manifest = instance_double('Bosh::Dev::VSphere::MicroBoshDeploymentManifest')
        Bosh::Dev::VSphere::MicroBoshDeploymentManifest
          .should_receive(:new)
          .with(ENV)
          .and_return(microbosh_deployment_manifest)

        director_uuid = instance_double('Bosh::Dev::Bat::DirectorUuid')
        Bosh::Dev::Bat::DirectorUuid
          .should_receive(:new)
          .with(bosh_cli_session)
          .and_return(director_uuid)

        bat_deployment_manifest = instance_double('Bosh::Dev::VSphere::BatDeploymentManifest')
        Bosh::Dev::VSphere::BatDeploymentManifest
          .should_receive(:new)
          .with(ENV, director_uuid, stemcell_archive)
          .and_return(bat_deployment_manifest)

        runner = instance_double('Bosh::Dev::Bat::Runner')
        Bosh::Dev::Bat::Runner.should_receive(:new).with(
          ENV,
          bat_helper,
          director_address,
          bosh_cli_session,
          stemcell_archive,
          microbosh_deployment_manifest,
          bat_deployment_manifest
        ).and_return(runner)

        expect(subject.build(bat_helper, 'net-type')).to eq(runner)
      end
    end
  end
end
