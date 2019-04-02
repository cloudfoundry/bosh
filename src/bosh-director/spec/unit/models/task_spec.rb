require 'spec_helper'
require 'logger'
require 'bosh/director/models/task'

module Bosh::Director::Models
  describe Task do
    let(:state) { :processing }
    let!(:task) do
      Bosh::Director::Models::Task.make(
        type: :update_deployment,
        state: state,
      )
    end

    describe '#cancellable?' do
      %w[processing queued].each do |state|
        context "when state is #{state}" do
          let(:state) { :processing }
          it 'returns true' do
            expect(task.cancellable?).to eq(true)
          end
        end
      end

      context 'when state is not processing or queued' do
        let(:state) { :cancelling }
        it 'returns false' do
          expect(task.cancellable?).to eq(false)
        end
      end
    end
  end
end
