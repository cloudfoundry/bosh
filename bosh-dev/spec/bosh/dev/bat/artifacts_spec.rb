require 'spec_helper'
require 'bosh/dev/bat/artifacts'

module Bosh::Dev::Bat
  describe Artifacts do
    subject { Artifacts.new(path, build, microbosh_definition, bat_definition) }
    let(:path) { '/fake/artifacts/path' }
    let(:build) { instance_double('Bosh::Dev::Build') }
    let(:microbosh_definition) { instance_double('Bosh::Stemcell::Definition') }
    let(:bat_definition) { instance_double('Bosh::Stemcell::Definition') }

    its(:micro_bosh_deployment_name) { should == 'microbosh' }
    its(:micro_bosh_deployment_dir)  { should eq("#{path}/microbosh") }

    describe '#bosh_stemcell_path' do
      it 'delegates to the build' do
        build
          .should_receive(:bosh_stemcell_path)
          .with(microbosh_definition, path)
          .and_return('bosh-stemcell-path')
        expect(subject.bosh_stemcell_path).to eq('bosh-stemcell-path')
      end
    end

    describe '#bat_stemcell_path' do
      it 'delegates to the build' do
        build
          .should_receive(:bosh_stemcell_path)
          .with(bat_definition, path)
          .and_return('bat-stemcell-path')

        expect(subject.bat_stemcell_path).to eq('bat-stemcell-path')
      end
    end

    describe '#prepare_directories' do
      before { FileUtils.stub(rm_rf: nil, mkdir_p: nil) }

      it 'removes the artifacts dir' do
        FileUtils.should_receive(:rm_rf).with(subject.path)
        subject.prepare_directories
      end

      it 'creates the microbosh depolyments dir (which is contained within artifacts dir)' do
        FileUtils.should_receive(:mkdir_p).with(subject.micro_bosh_deployment_dir)
        subject.prepare_directories
      end
    end
  end
end
