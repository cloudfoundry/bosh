require 'spec_helper'

module Bosh::Director
  describe Errand::ParallelStep do
    subject(:parallel_step) { Errand::ParallelStep.new(4, [ errand_step1, errand_step2 ]) }
    let(:errand_step1) { instance_double(Errand::LifecycleErrandStep, ignore_cancellation?: false) }
    let(:errand_step2) { instance_double(Errand::LifecycleErrandStep, ignore_cancellation?: false) }
    let(:checkpoint_block) { Proc.new{} }
    let(:mutex) { Mutex.new }
    let(:resource) { ConditionVariable.new }

    describe '#prepare' do
      it 'runs all prepare steps in parallel' do
        expect(errand_step1).to receive(:prepare) do
          mutex.synchronize { resource.wait(mutex) }
        end
        expect(errand_step2).to receive(:prepare) do
          mutex.synchronize { resource.signal }
        end

        subject.prepare
      end
    end

    describe '#run' do
      let(:result1) { instance_double(Bosh::Director::Errand::Result) }
      let(:result2) { instance_double(Bosh::Director::Errand::Result) }

      it 'runs all the steps in parallel' do
        expect(errand_step1).to receive(:run) do |args, &blk|
          expect(blk).to be(checkpoint_block)
          mutex.synchronize { resource.wait(mutex) }
          result1
        end

        expect(errand_step2).to receive(:run) do |args, &blk|
          expect(blk).to be(checkpoint_block)
          mutex.synchronize { resource.signal }
          result2
        end

        results = subject.run(&checkpoint_block)
        expect(results).to contain_exactly(result1, result2)
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
