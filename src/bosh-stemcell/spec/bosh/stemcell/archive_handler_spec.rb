require 'spec_helper'
require 'bosh/stemcell/archive_handler'

module Bosh::Stemcell
  describe ArchiveHandler do
    subject(:archiver) { described_class.new }

    let(:shell) { instance_double(Bosh::Core::Shell) }

    before do
      allow(Bosh::Core::Shell).to receive(:new).and_return(shell)
    end

    describe 'compress' do
      it 'compresses the given directory' do
        expect(shell).to receive(:run).with('sudo tar -cz -f some.tar.gz -C some_dir .')

        archiver.compress('some_dir', 'some.tar.gz')
      end
    end
  end
end
