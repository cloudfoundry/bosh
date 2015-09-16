require 'spec_helper'
require 'bosh/dev/bat_helper'

module Bosh::Dev
  describe BatHelper do
    include FakeFS::SpecHelpers

    subject { described_class.new(bat_runner_builder, artifacts, build, networking_type, stemcell) }

    let(:bat_runner_builder) { instance_double('Bosh::Dev::Aws::RunnerBuilder') }

    let(:infrastructure) do
      instance_double(
        'Bosh::Stemcell::Infrastructure::Base',
        name: 'infrastructure-name',
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
    let(:build) { instance_double('Bosh::Dev::Build', download_stemcell: nil, number: 'build-number') }

    let(:artifacts) { instance_double('Bosh::Dev::Bat::Artifacts', prepare_directories: nil, path: artifacts_path) }

    let(:artifacts_path) do
      '/tmp/ci-artifacts/infrastructure-name/networking-type/operating-system-name/operating-system-version/agent-name/deployments'
    end

    let(:stemcell) { instance_double('Bosh::Stemcell::Stemcell') }

    describe '.for_rake_args' do
      let(:light) { false }
      let(:rake_args) do
        Struct.new(
          :infrastructure_name,
          :hypervisor_name,
          :operating_system_name,
          :operating_system_version,
          :net_type,
          :agent_name,
          :light,
          :disk_format,
        ).new(
          'infrastructure-name',
          'hypervisor-name',
          'operating-system-name',
          'operating-system-version',
          networking_type,
          'agent-name',
          light,
          'disk-format'
        )
      end

      before do
        expect(described_class)
        .to receive(:runner_builder_for_infrastructure_name)
        .with('infrastructure-name')
        .and_return(bat_runner_builder)
      end

      it 'returns bat helper configured with rake arguments' do
        expect(Build).to receive(:candidate).and_return(build)

        expect(Bosh::Stemcell::Definition).to receive(:for)
          .with(
            'infrastructure-name',
            'hypervisor-name',
            'operating-system-name',
            'operating-system-version',
            'agent-name',
            light
          ).and_return(definition)

        expect(Bosh::Stemcell::Stemcell).to receive(:new).and_return(stemcell)

        bat_helper = instance_double('Bosh::Dev::BatHelper')
        expect(described_class)
          .to receive(:new)
          .with(bat_runner_builder, instance_of(Bosh::Dev::Bat::Artifacts), build, networking_type, stemcell)
          .and_return(bat_helper)

        expect(described_class.for_rake_args(rake_args)).to eq bat_helper
      end

      context 'when WORKSPACE is set' do
        before { stub_const('ENV', {'WORKSPACE' => '/fake-workspace'}) }

        it 'builds artifacts inside of workspace' do
          expect(Bosh::Stemcell::Definition).to receive(:for)
          .with(
            'infrastructure-name',
            'hypervisor-name',
            'operating-system-name',
            'operating-system-version',
            'agent-name',
            light
          ).and_return(definition)

          expect(Bosh::Dev::Bat::Artifacts).to receive(:new) do |artifacts_path, _, _|
            expect(artifacts_path).to match %r{^/fake-workspace}
          end

          described_class.for_rake_args(rake_args)
        end
      end
    end

    describe '#deploy_microbosh_and_run_bats' do
      before { allow(bat_runner_builder).to receive(:build).and_return(bat_runner) }
      let(:bat_runner) { instance_double('Bosh::Dev::Bat::Runner', deploy_bats_microbosh: nil, run_bats: nil) }

      before { allow(artifacts).to receive(:prepare_directories) }

      it 'removes the artifacts dir' do
        expect(artifacts).to receive(:prepare_directories)
        subject.deploy_microbosh_and_run_bats
      end

      it 'downloads stemcells for the specified infrastructure' do
        expect(build).to receive(:download_stemcell).with(
          stemcell,
          artifacts_path,
        )
        subject.deploy_microbosh_and_run_bats
      end

      it 'uses bats runner to deploy microbosh and run bats' do
        expect(bat_runner_builder).to receive(:build)
          .with(artifacts, networking_type)
          .and_return(bat_runner)

        expect(bat_runner).to receive(:deploy_bats_microbosh)
        expect(bat_runner).to receive(:run_bats)
        subject.deploy_microbosh_and_run_bats
      end
    end

    describe '#deploy_bats_microbosh' do
      before { allow(bat_runner_builder).to receive(:build).and_return(bat_runner) }
      let(:bat_runner) { instance_double('Bosh::Dev::Bat::Runner', deploy_bats_microbosh: nil) }

      before { allow(artifacts).to receive(:prepare_directories) }

      it 'removes the artifacts dir' do
        expect(artifacts).to receive(:prepare_directories)
        subject.deploy_bats_microbosh
      end

      it 'downloads stemcells for the specified infrastructure' do
        expect(build).to receive(:download_stemcell).with(
          stemcell,
          artifacts_path,
        )
        subject.deploy_bats_microbosh
      end

      it 'uses bats runner to deploy microbosh' do
        expect(bat_runner_builder).to receive(:build)
        .with(artifacts, networking_type)
        .and_return(bat_runner)

        expect(bat_runner).to receive(:deploy_bats_microbosh)
        subject.deploy_bats_microbosh
      end
    end

    describe '#run_bats' do
      it 'uses bats runner to run bats without deploying microbosh ' +
         '(assumption is user already has microbosh)' do
        bat_runner = instance_double('Bosh::Dev::Bat::Runner')
        expect(bat_runner_builder)
          .to receive(:build)
          .with(artifacts, networking_type)
          .and_return(bat_runner)

        expect(bat_runner).to receive(:run_bats)
        subject.run_bats
      end
    end
  end
end
