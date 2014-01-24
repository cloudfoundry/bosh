require 'spec_helper'
require 'bosh/dev/bat_helper'

module Bosh::Dev
  describe BatHelper do
    include FakeFS::SpecHelpers

    subject { described_class.new(bat_runner_builder, microbosh_definition, bat_definition, build, networking_type) }

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
      )
    end

    let(:agent) { instance_double('Bosh::Stemcell::Agent::Go', name: 'agent-name') }
    let(:ruby_agent) { instance_double('Bosh::Stemcell::Agent::Ruby', name: 'agent-name') }

    let(:microbosh_definition) do
      instance_double(
        'Bosh::Stemcell::Definition',
        infrastructure: infrastructure,
        operating_system: operating_system,
        agent: ruby_agent,
      )
    end

    let(:bat_definition) do
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

    let(:artifacts_path) { '/tmp/ci-artifacts/infrastructure-name/networking-type/operating-system-name/agent-name/deployments' }

    describe '#initialize' do
      it 'builds an artifacts object' do
        subject

        expect(Bosh::Dev::Bat::Artifacts).to have_received(:new)
                                             .with(artifacts_path, build, microbosh_definition, bat_definition)
      end
    end

    describe '.for_rake_args' do
      it 'returns bat helper configured with rake arguments' do
        rake_args = Struct.new(
          :infrastructure_name,
          :operating_system_name,
          :net_type,
          :agent_name
        ).new('infrastructure-name', 'operating-system-name', networking_type, 'agent-name')

        described_class
          .should_receive(:runner_builder_for_infrastructure_name)
          .with('infrastructure-name')
          .and_return(bat_runner_builder)

        Build.should_receive(:candidate).and_return(build)

        expect(Bosh::Stemcell::Definition).to receive(:for)
                                              .with('infrastructure-name', 'operating-system-name', 'ruby')
                                              .and_return(microbosh_definition)
        expect(Bosh::Stemcell::Definition).to receive(:for)
                                              .with('infrastructure-name', 'operating-system-name', 'agent-name')
                                              .and_return(bat_definition)

        bat_helper = instance_double('Bosh::Dev::BatHelper')
        described_class
          .should_receive(:new)
          .with(bat_runner_builder, microbosh_definition, bat_definition, build, networking_type)
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

      context 'microbosh and bat stemcell definitions are the same' do
        let(:bat_definition) { microbosh_definition }

        it 'downloads stemcells for the specified infrastructure' do
          build.should_receive(:download_stemcell).with(
            'bosh-stemcell',
            bat_definition,
            false,
            artifacts_path,
          )
          subject.deploy_microbosh_and_run_bats
        end
      end

      context 'microbosh and bat stemcell definitions are different' do
        it 'downloads stemcells for the specified infrastructure' do
          build.should_receive(:download_stemcell).with(
            'bosh-stemcell',
            bat_definition,
            false,
            artifacts_path,
          )

          build.should_receive(:download_stemcell).with(
            'bosh-stemcell',
            microbosh_definition,
            false,
            artifacts_path,
          )
          subject.deploy_microbosh_and_run_bats
        end
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
