require 'spec_helper'
require 'bosh/dev/bat/artifacts'

module Bosh::Dev::Bat
  describe Artifacts do
    subject { Artifacts.new(path, build, definition) }
    let(:path) { '/fake/artifacts/path' }
    let(:build) { instance_double('Bosh::Dev::Build') }
    let(:definition) { instance_double('Bosh::Stemcell::Definition') }

    its(:micro_bosh_deployment_name) { should == 'microbosh' }
    its(:micro_bosh_deployment_dir)  { should eq("#{path}/microbosh") }

    describe '#stemcell_path' do
      it 'delegates to the build' do
        build
          .should_receive(:bosh_stemcell_path)
          .with(definition, path)
          .and_return('bosh-stemcell-path')
        expect(subject.stemcell_path).to eq('bosh-stemcell-path')
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
