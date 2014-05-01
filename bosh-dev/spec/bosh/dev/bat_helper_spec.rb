require 'spec_helper'
require 'bosh/dev/bat_helper'

module Bosh::Dev
  describe BatHelper do
    include FakeFS::SpecHelpers

    subject { described_class.new(bat_runner_builder, definition, build, networking_type) }

    let(:bat_runner_builder) { instance_double('Bosh::Dev::Aws::RunnerBuilder') }

    let(:infrastructure) do
      instance_double(
        'Bosh::Stemcell::Infrastructure::Base',
        name: 'infrastructure-name',
        light?: false,
      )
    end

    let(:operating_system) do
      instance_double(
        'Bosh::Stemcell::OperatingSystem::Base',
        name: 'operating-system-name',
        version: 'operating-system-version',
      )
    end

    let(:agent) { instance_double('Bosh::Stemcell::Agent::Go', name: 'agent-name') }

    let(:definition) do
      instance_double(
        'Bosh::Stemcell::Definition',
        infrastructure: infrastructure,
        operating_system: operating_system,
        agent: agent,
      )
    end

    let(:networking_type) { 'networking-type' }
    let(:build) { instance_double('Bosh::Dev::Build', download_stemcell: nil) }

    let(:artifacts) { instance_double('Bosh::Dev::Bat::Artifacts', prepare_directories: nil, path: artifacts_path) }
    before { allow(Bosh::Dev::Bat::Artifacts).to receive(:new).and_return(artifacts) }

    let(:artifacts_path) do
      '/tmp/ci-artifacts/infrastructure-name/networking-type/operating-system-name/operating-system-version/agent-name/deployments'
    end

    describe '#initialize' do
      it 'builds an artifacts object' do
        subject

        expect(Bosh::Dev::Bat::Artifacts).to have_received(:new)
                                             .with(artifacts_path, build, definition)
      end
    end

    describe '.for_rake_args' do
      it 'returns bat helper configured with rake arguments' do
        rake_args = Struct.new(
          :infrastructure_name,
          :operating_system_name,
          :operating_system_version,
          :net_type,
          :agent_name
        ).new('infrastructure-name', 'operating-system-name', 'operating-system-version', networking_type, 'agent-name')

        described_class
          .should_receive(:runner_builder_for_infrastructure_name)
          .with('infrastructure-name')
          .and_return(bat_runner_builder)

        Build.should_receive(:candidate).and_return(build)

        expect(Bosh::Stemcell::Definition).to receive(:for)
                                              .with('infrastructure-name', 'operating-system-name', 'operating-system-version', 'agent-name')
                                              .and_return(definition)

        bat_helper = instance_double('Bosh::Dev::BatHelper')
        described_class
          .should_receive(:new)
          .with(bat_runner_builder, definition, build, networking_type)
          .and_return(bat_helper)

        expect(described_class.for_rake_args(rake_args)).to eq bat_helper
      end
    end

    describe '#deploy_microbosh_and_run_bats' do
      before { bat_runner_builder.stub(build: bat_runner) }
      let(:bat_runner) { instance_double('Bosh::Dev::Bat::Runner', deploy_microbosh_and_run_bats: nil) }

      before { allow(artifacts).to receive(:prepare_directories) }

      it 'removes the artifacts dir' do
        subject.deploy_microbosh_and_run_bats
        expect(artifacts).to have_received(:prepare_directories)
      end

      it 'downloads stemcells for the specified infrastructure' do
        build.should_receive(:download_stemcell).with(
          'bosh-stemcell',
          definition,
          false,
          artifacts_path,
        )
        subject.deploy_microbosh_and_run_bats
      end

      it 'uses bats runner to deploy microbosh and run bats' do
        bat_runner_builder
          .should_receive(:build)
          .with(artifacts, networking_type)
          .and_return(bat_runner)

        bat_runner.should_receive(:deploy_microbosh_and_run_bats)
        subject.deploy_microbosh_and_run_bats
      end
    end

    describe '#run_bats' do
      it 'uses bats runner to run bats without deploying microbosh ' +
         '(assumption is user already has microbosh)' do
        bat_runner = instance_double('Bosh::Dev::Bat::Runner')
        bat_runner_builder
          .should_receive(:build)
          .with(artifacts, networking_type)
          .and_return(bat_runner)

        bat_runner.should_receive(:run_bats)
        subject.run_bats
      end
    end
  end
end
