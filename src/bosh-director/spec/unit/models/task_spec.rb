require 'spec_helper'
require 'bosh/director/models/task'

module Bosh::Director::Models
  describe Task do
    describe '#cancellable?' do
      subject(:task) { Task.new(state: state) }

      context "when state is processing" do
        let(:state) { :processing }

        it 'returns true' do
          expect(task.cancellable?).to eq(true)
        end
      end

      context "when state is queued" do
        let(:state) { :queued }

        it 'returns true' do
          expect(task.cancellable?).to eq(true)
        end
      end

      context 'when state is cancelling' do
        let(:state) { :cancelling }

        it 'returns false' do
          expect(task.cancellable?).to eq(false)
        end
      end

      context 'when state is done' do
        let(:state) { :done }

        it 'returns false' do
          expect(task.cancellable?).to eq(false)
        end
      end
    end
  end
end
