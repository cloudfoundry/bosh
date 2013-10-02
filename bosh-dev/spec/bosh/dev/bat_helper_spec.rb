require 'spec_helper'
require 'bosh/dev/bat_helper'

module Bosh::Dev
  describe BatHelper do
    include FakeFS::SpecHelpers

    subject { described_class.new(infrastructure_name, operating_system_name, 'manual') }

    before { Bosh::Stemcell::Infrastructure.should_receive(:for).and_return(infrastructure) }
    let(:infrastructure) { instance_double('Bosh::Stemcell::Infrastructure::Base', name: infrastructure_name, light?: light) }
    let(:infrastructure_name) { 'infrastructure-name' }
    
    before { Bosh::Stemcell::OperatingSystem.should_receive(:for).and_return(operating_system) }
    let(:operating_system) { instance_double('Bosh::Stemcell::OperatingSystem::Base', name: operating_system_name) }
    let(:operating_system_name) { 'operating-system-name' }

    expected_artifacts_dir = '/tmp/ci-artifacts/infrastructure-name/operating-system-name'

    let(:light) { false }
    
    before { Build.stub(candidate: build) }
    let(:build) { instance_double('Bosh::Dev::Build', download_stemcell: nil) }

    describe '#initialize' do
      its(:infrastructure)   { should == infrastructure }
      its(:operating_system) { should == operating_system }

      its(:micro_bosh_deployment_name) { should == 'microbosh' }
      its(:artifacts_dir)              { should eq("#{expected_artifacts_dir}/deployments") }
      its(:micro_bosh_deployment_dir)  { should eq("#{expected_artifacts_dir}/deployments/microbosh") }
    end

    describe '#run_rake' do
      before { Rake::Task.stub(:[]).and_return(spec_system_micro_task) }
      let(:spec_system_micro_task) { instance_double('Rake::Task', invoke: nil) }

      before { FileUtils.stub(rm_rf: nil, mkdir_p: nil) }

      it 'removes the artifacts dir' do
        FileUtils.should_receive(:rm_rf).with(subject.artifacts_dir)
        subject.run_rake
      end

      it 'creates the microbosh depolyments dir (which is contained within artifacts dir)' do
        FileUtils.should_receive(:mkdir_p).with(subject.micro_bosh_deployment_dir)
        subject.run_rake
      end

      it 'downloads stemcells for the specified infrastructure' do
        build.should_receive(:download_stemcell).with(
          name: 'bosh-stemcell',
          infrastructure: infrastructure,
          operating_system: operating_system,
          light: light,
          output_directory: "#{expected_artifacts_dir}/deployments",
        )
        subject.run_rake
      end

      it 'invokes the spec:system:micro rake task' do
        Rake::Task
          .should_receive(:[])
          .with("spec:system:micro")
          .and_return(spec_system_micro_task)
        spec_system_micro_task
          .should_receive(:invoke)
          .with('infrastructure-name', 'operating-system-name', 'manual')
        subject.run_rake
      end
    end

    describe '#bosh_stemcell_path' do
      it 'delegates to the build' do
        build
          .should_receive(:bosh_stemcell_path)
          .with(infrastructure, operating_system, "#{expected_artifacts_dir}/deployments")
          .and_return('bosh-stemcell-path')
        expect(subject.bosh_stemcell_path).to eq('bosh-stemcell-path')
      end
    end
  end
end
