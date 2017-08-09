require 'spec_helper'

module Bosh::Director
  describe Errand::ParallelStep do
    subject(:parallel_step) { Errand::ParallelStep.new(4, errand_name, deployment_model, [ errand_step1, errand_step2 ]) }
    let(:deployment_model) { Bosh::Director::Models::Deployment.make }
    let(:errand_name) { 'errand-name' }
    let(:errand_step1) { instance_double(Errand::LifecycleErrandStep, ignore_cancellation?: false) }
    let(:errand_step2) { instance_double(Errand::LifecycleErrandStep, ignore_cancellation?: false) }
    let(:checkpoint_block) { Proc.new{} }
    let(:mutex) { Mutex.new }
    let(:resource) { ConditionVariable.new }
    let(:good_state_hash) { ::Digest::SHA1.hexdigest('cornedbeefdeadbeef') }

    before do
      allow(errand_step1).to receive(:state_hash).and_return('deadbeef')
      allow(errand_step2).to receive(:state_hash).and_return('cornedbeef')
    end

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
      let(:result1) { instance_double(Bosh::Director::Errand::Result, successful?: true) }
      let(:result2) { instance_double(Bosh::Director::Errand::Result, successful?: true) }

      before do
        allow(errand_step1).to receive(:run).and_return(result1)
        allow(errand_step2).to receive(:run).and_return(result2)
      end

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

      it 'creates an errand run record with the state hash' do
        expect { subject.run(&checkpoint_block) }.to change { Models::ErrandRun.count }.from(0).to(1)
        errand_run = Models::ErrandRun.first
        expect(errand_run.deployment).to eq(deployment_model)
        expect(errand_run.errand_name).to eq(errand_name)
        expect(errand_run.successful_state_hash).to eq(subject.state_hash)
      end

      context 'when there is a record of previous successful run' do
        let!(:errand_run) do
          Models::ErrandRun.make(
            deployment: deployment_model,
            errand_name: errand_name,
            successful_state_hash: 'someotherstate')
        end

        context 'when the errand succeeds' do
          it 'updates the successful_state_hash for the record' do
            expect { subject.run(&checkpoint_block) }.to change { errand_run.refresh.successful_state_hash }.from('someotherstate').to(good_state_hash)
          end
        end

        context 'when a step raises' do
          before { allow(errand_step1).to receive(:run).and_raise('Oh noes!!!') }

          it 'updates the successful_state_hash to be an empty string' do
            expect { subject.run(&checkpoint_block) }.to raise_error('Oh noes!!!')

            expect(errand_run.refresh.successful_state_hash).to eq('')
          end
        end

        context 'when a step is unsuccessful' do
          before { allow(result1).to receive(:successful?).and_return(false) }

          it 'updates the successful_state_hash to be an empty string' do
            subject.run(&checkpoint_block)

            expect(errand_run.refresh.successful_state_hash).to eq('')
          end
        end
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

    describe '#state_hash' do
      it 'returns digest of ordered substep hashes' do
        expect(subject.state_hash).to eq(good_state_hash)
      end
    end

    describe '#has_not_changed_since_last_success?' do
      context 'when there is no previous run' do
        it 'returns false' do
          expect(subject.has_not_changed_since_last_success?).to eq(false)
        end
      end

      context 'when there is a previous run' do
        context 'when the last run hash matches the current hash' do
          before do
            Models::ErrandRun.make(
              deployment: deployment_model,
              errand_name: errand_name,
              successful_state_hash: good_state_hash
            )
          end

          it 'returns true' do
            expect(subject.has_not_changed_since_last_success?).to eq(true)
          end
        end

        context 'when the last run hash does not match the current hash' do
          before do
            Models::ErrandRun.make(
              deployment: deployment_model,
              errand_name: errand_name,
              successful_state_hash: ::Digest::SHA1.hexdigest('pastramideadbeef')
            )
          end

          it 'returns false' do
            expect(subject.has_not_changed_since_last_success?).to eq(false)
          end
        end
      end
    end
  end
end
