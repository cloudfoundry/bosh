require 'spec_helper'
require 'bosh/dev/bat_helper'
require 'bosh/dev/openstack/runner_builder'

module Bosh::Dev::Openstack
  describe RunnerBuilder do
    describe '#build' do
      it 'returns openstack runner with injected env and proper director address' do
        bat_helper = instance_double(
          'Bosh::Dev::BatHelper',
          bosh_stemcell_path: 'stemcell-path',
        )

        director_address = instance_double('Bosh::Dev::Bat::DirectorAddress')
        class_double('Bosh::Dev::Bat::DirectorAddress').as_stubbed_const
          .should_receive(:from_env)
          .with(ENV, 'BOSH_OPENSTACK_VIP_DIRECTOR_IP')
          .and_return(director_address)

        bosh_cli_session = instance_double('Bosh::Dev::BoshCliSession')
        class_double('Bosh::Dev::BoshCliSession').as_stubbed_const
          .should_receive(:new)
          .with(no_args)
          .and_return(bosh_cli_session)

        stemcell_archive = instance_double(
          'Bosh::Stemcell::Archive',
          version: 'stemcell-archive-version',
        )
        class_double('Bosh::Stemcell::Archive').as_stubbed_const
          .should_receive(:new)
          .with('stemcell-path')
          .and_return(stemcell_archive)

        microbosh_deployment_manifest = instance_double('Bosh::Dev::Openstack::MicroBoshDeploymentManifest')
        class_double('Bosh::Dev::Openstack::MicroBoshDeploymentManifest').as_stubbed_const
          .should_receive(:new)
          .with(ENV, 'net-type')
          .and_return(microbosh_deployment_manifest)

        microbosh_deployment_cleaner = instance_double('Bosh::Dev::Openstack::MicroBoshDeploymentCleaner')
        class_double('Bosh::Dev::Openstack::MicroBoshDeploymentCleaner').as_stubbed_const
          .should_receive(:new)
          .with(microbosh_deployment_manifest)
          .and_return(microbosh_deployment_cleaner)

        director_uuid = instance_double('Bosh::Dev::Bat::DirectorUuid')
        class_double('Bosh::Dev::Bat::DirectorUuid').as_stubbed_const
          .should_receive(:new)
          .with(bosh_cli_session)
          .and_return(director_uuid)

        bat_deployment_manifest = instance_double('Bosh::Dev::Openstack::BatDeploymentManifest')
        class_double('Bosh::Dev::Openstack::BatDeploymentManifest').as_stubbed_const
          .should_receive(:new)
          .with(ENV, 'net-type', director_uuid, stemcell_archive)
          .and_return(bat_deployment_manifest)

        runner = instance_double('Bosh::Dev::Bat::Runner')
        class_double('Bosh::Dev::Bat::Runner').as_stubbed_const
          .should_receive(:new).with(
            ENV,
            bat_helper,
            director_address,
            bosh_cli_session,
            stemcell_archive,
            microbosh_deployment_manifest,
            bat_deployment_manifest,
            microbosh_deployment_cleaner,
          ).and_return(runner)

        expect(subject.build(bat_helper, 'net-type')).to eq(runner)
      end
    end
  end
end
