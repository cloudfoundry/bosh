require 'spec_helper'
require 'bosh/dev/bat_helper'
require 'bosh/dev/aws/runner_builder'

module Bosh::Dev::Aws
  describe RunnerBuilder do
    describe '#build' do
      it 'builds runner' do
        bat_helper = instance_double(
          'Bosh::Dev::BatHelper',
          bosh_stemcell_path: 'bosh-stemcell-path',
        )

        director_address = instance_double('Bosh::Dev::Bat::DirectorAddress')
        Bosh::Dev::Bat::DirectorAddress
          .should_receive(:resolved_from_env)
          .with(ENV, 'BOSH_VPC_SUBDOMAIN')
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
          .with('bosh-stemcell-path')
          .and_return(stemcell_archive)

        microbosh_deployment_manifest = instance_double('Bosh::Dev::Aws::MicroBoshDeploymentManifest')
        Bosh::Dev::Aws::MicroBoshDeploymentManifest
          .should_receive(:new)
          .with(ENV, bosh_cli_session)
          .and_return(microbosh_deployment_manifest)

        bat_deployment_manifest = instance_double('Bosh::Dev::Aws::BatDeploymentManifest')
        Bosh::Dev::Aws::BatDeploymentManifest
          .should_receive(:new)
          .with(ENV, bosh_cli_session, stemcell_archive)
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
