require 'spec_helper'
require 'bosh/dev/bat/artifacts'

module Bosh::Dev::Bat
  describe Artifacts do
    subject { Artifacts.new(path, stemcell) }
    let(:path) { '/fake/artifacts/path' }
    let(:stemcell) { instance_double('Bosh::Stemcell::Stemcell', name: 'fake-stemcell-name') }

    its(:micro_bosh_deployment_name) { should eq('microbosh') }
    its(:micro_bosh_deployment_dir)  { should eq("#{path}/microbosh") }

    describe '#stemcell_path' do
      it 'returns the stemcell name at the path' do
        expect(subject.stemcell_path).to eq('/fake/artifacts/path/fake-stemcell-name')
      end
    end

    describe '#prepare_directories' do
      before { allow(FileUtils).to receive_messages(rm_rf: nil, mkdir_p: nil) }

      it 'removes the artifacts dir' do
        expect(FileUtils).to receive(:rm_rf).with(subject.path)
        subject.prepare_directories
      end

      it 'creates the microbosh depolyments dir (which is contained within artifacts dir)' do
        expect(FileUtils).to receive(:mkdir_p).with(subject.micro_bosh_deployment_dir)
        subject.prepare_directories
      end
    end
  end
end
