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
      )
    end

    let(:agent) do
      instance_double(
        'Bosh::Stemcell::Agent::Go'
      )
    end

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

        allow(Bosh::Stemcell::Definition).to receive(:for).and_return(definition)

        bat_helper = instance_double('Bosh::Dev::BatHelper')
        described_class
          .should_receive(:new)
          .with(bat_runner_builder, definition, build, networking_type)
          .and_return(bat_helper)

        expect(described_class.for_rake_args(rake_args)).to eq bat_helper

        expect(Bosh::Stemcell::Definition).to have_received(:for)
                                           .with('infrastructure-name', 'operating-system-name', 'agent-name')
      end
    end

    let(:expected_artifacts_dir) { '/tmp/ci-artifacts/infrastructure-name/networking-type/operating-system-name' }

    describe '#initialize' do
      its(:infrastructure)             { should == infrastructure }
      its(:operating_system)           { should == operating_system }
      its(:agent)                      { should == agent }
      its(:micro_bosh_deployment_name) { should == 'microbosh' }
      its(:artifacts_dir)              { should eq("#{expected_artifacts_dir}/deployments") }
      its(:micro_bosh_deployment_dir)  { should eq("#{expected_artifacts_dir}/deployments/microbosh") }

      context 'when there is no networking type defined' do
        let(:networking_type) { nil }
        let(:expected_artifacts_dir) { '/tmp/ci-artifacts/infrastructure-name/operating-system-name' }

        its(:artifacts_dir)              { should eq("#{expected_artifacts_dir}/deployments") }
        its(:micro_bosh_deployment_dir)  { should eq("#{expected_artifacts_dir}/deployments/microbosh") }
      end
    end

    describe '#deploy_microbosh_and_run_bats' do
      before { bat_runner_builder.stub(build: bat_runner) }
      let(:bat_runner) { instance_double('Bosh::Dev::Bat::Runner', deploy_microbosh_and_run_bats: nil) }

      before { FileUtils.stub(rm_rf: nil, mkdir_p: nil) }

      it 'removes the artifacts dir' do
        FileUtils.should_receive(:rm_rf).with(subject.artifacts_dir)
        subject.deploy_microbosh_and_run_bats
      end

      it 'creates the microbosh depolyments dir (which is contained within artifacts dir)' do
        FileUtils.should_receive(:mkdir_p).with(subject.micro_bosh_deployment_dir)
        subject.deploy_microbosh_and_run_bats
      end

      it 'downloads stemcells for the specified infrastructure' do
        build.should_receive(:download_stemcell).with(
          'bosh-stemcell',
          definition,
          false,
          "#{expected_artifacts_dir}/deployments",
        )
        subject.deploy_microbosh_and_run_bats
      end

      it 'uses bats runner to deploy microbosh and run bats' do
        bat_runner_builder
          .should_receive(:build)
          .with(subject, networking_type)
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
          .with(subject, networking_type)
          .and_return(bat_runner)

        bat_runner.should_receive(:run_bats)
        subject.run_bats
      end
    end

    describe '#bosh_stemcell_path' do
      it 'delegates to the build' do
        build
          .should_receive(:bosh_stemcell_path)
          .with(definition, "#{expected_artifacts_dir}/deployments")
          .and_return('bosh-stemcell-path')
        expect(subject.bosh_stemcell_path).to eq('bosh-stemcell-path')
      end
    end
  end
end
