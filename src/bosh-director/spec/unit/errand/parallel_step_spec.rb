require 'spec_helper'

module Bosh::Director
  describe Errand::ParallelStep do
    subject(:parallel_step) { Errand::ParallelStep.new(4, [ errand_step1, errand_step2 ]) }
    let(:errand_step1) { instance_double(Errand::LifecycleErrandStep, ignore_cancellation?: false) }
    let(:errand_step2) { instance_double(Errand::LifecycleErrandStep, ignore_cancellation?: false) }
    let(:checkpoint_block) { Proc.new{} }

    describe '#run' do
      it 'runs all the steps in parallel' do
        mutex = Mutex.new
        resource = ConditionVariable.new

        expect(errand_step1).to receive(:run) do |args, &blk|
          expect(blk).to be(checkpoint_block)

          mutex.synchronize do
            resource.wait(mutex)
          end
          'step1'
        end
        expect(errand_step2).to receive(:run) do |args, &blk|
          expect(blk).to be(checkpoint_block)

          mutex.synchronize {
            resource.signal
          }
          'step2'
        end

        results = subject.run(&checkpoint_block)
        expect(results.split("\n")).to contain_exactly('step1', 'step2')
      end
    end

    describe '#ignore_cancellation?' do
      context 'no steps ignore cancellation' do
        it 'does not ignore cancellation' do
          expect(subject.ignore_cancellation?).to be(false)
        end
      end

      context 'at least one step ignores cancellation' do
        it 'ignores cancellation' do
          allow(errand_step1).to receive(:ignore_cancellation?).and_return(true)

          expect(subject.ignore_cancellation?).to be(true)
        end
      end
    end
  end
end
