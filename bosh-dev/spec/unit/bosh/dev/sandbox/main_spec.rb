require 'spec_helper'
require 'bosh/dev/sandbox/main'

module Bosh::Dev::Sandbox
  describe Main do
    subject(:sandbox) { Main.new({}, nil, 0, logger) }

    describe '#run' do
      before do
        allow(sandbox).to receive(:start)
        allow(sandbox).to receive(:stop)
        allow(sandbox).to receive(:loop)
      end

      it 'starts the sandbox' do
        sandbox.run
        expect(sandbox).to have_received(:start)
      end

      it 'waits for an interrupt from the user to stop' do
        allow(sandbox).to receive(:loop).and_raise(Interrupt)
        sandbox.run
        expect(sandbox).to have_received(:loop)
        expect(sandbox).to have_received(:stop)
      end

      it 'always stops the standbox' do
        allow(sandbox).to receive(:loop).and_raise('Something unexpected and bad happened')
        expect { sandbox.run }.to raise_error(/unexpected/)
        expect(sandbox).to have_received(:stop)
      end
    end
  end
end
