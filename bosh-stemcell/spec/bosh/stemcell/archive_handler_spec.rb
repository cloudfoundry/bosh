require 'spec_helper'
require 'bosh/stemcell/archive_handler'

module Bosh::Stemcell
  describe ArchiveHandler do
    subject(:archiver) { described_class.new }

    let(:shell) { instance_double(Bosh::Core::Shell) }

    before do
      allow(Bosh::Core::Shell).to receive(:new).and_return(shell)
    end

    describe 'extract(path)' do
      it 'extracts a given archive inside a given location' do
        expect(shell).to receive(:run).with('sudo mkdir -p some_dir').ordered
        expect(shell).to receive(:run).with('sudo tar -xz -f some.tar.gz -C some_dir').ordered

        archiver.extract('some.tar.gz', 'some_dir')
      end
    end

    describe 'compress' do
      it 'compresses the given directory' do
        expect(shell).to receive(:run).with('sudo tar -cz -f some.tar.gz some_dir')

        archiver.compress('some_dir', 'some.tar.gz')
      end
    end
  end
end
