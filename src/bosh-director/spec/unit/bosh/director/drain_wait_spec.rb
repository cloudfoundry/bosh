require 'spec_helper'

module Bosh::Director
  describe 'Drain wait handling' do
    let(:deadline) { Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3_600 }

    it 'rejects excessive agent waits before sleeping' do
      expect(Stopper).not_to receive(:sleep)
      expect { Stopper.send(:interruptible_drain_sleep, 100_000, deadline) }.to raise_error(DirectorError, /wait budget/)
    end

    it 'checks cancellation between short sleep intervals' do
      allow(Stopper).to receive(:sleep)
      expect(Config).to receive(:job_cancelled?).ordered
      expect(Config).to receive(:job_cancelled?).ordered.and_raise(TaskCancelled)
      expect { Stopper.send(:interruptible_drain_sleep, 3, deadline) }.to raise_error(TaskCancelled)
      expect(Stopper).to have_received(:sleep).once.with(1)
    end

    it 'bounds repeated negative drain responses' do
      stub_const('Bosh::Director::Stopper::MAX_DRAIN_POLLS', 2)
      allow(Stopper).to receive(:sleep)
      client = double('agent', drain: -1)
      logger = double('logger', info: nil)
      expect do
        Stopper.send(:wait_for_dynamic_drain, -1, 'instance', client, logger, deadline)
      end.to raise_error(DirectorError, /wait budget/)
    end
  end
end
