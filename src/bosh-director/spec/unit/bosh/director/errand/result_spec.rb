require 'spec_helper'

module Bosh::Director
  describe Errand::Result do
    let(:instance) { instance_double(DeploymentPlan::Instance, instance_group_name: 'instance-group', uuid: 'dead-beef') }

    describe '.from_agent_task_result' do
      let(:errand_name) { 'errand-name' }
      let(:agent_run_errand_result) do
        {
          'exit_code' => 123,
          'stdout' => 'fake-stdout',
          'stderr' => 'fake-stderr',
        }
      end

      %w(exit_code stdout stderr).each do |field_name|
        it "raises an error when #{field_name} is missing from agent run errand result" do
          invalid_errand_result = agent_run_errand_result.reject { |k, _| k == field_name }
          expect {
            described_class.from_agent_task_results(instance, errand_name, invalid_errand_result, nil)
          }.to raise_error(AgentInvalidTaskResult, /#{field_name}.*missing/i)
        end
      end

      it 'does not raise an error if fetch_logs results is nil (not available)' do
        expect {
          described_class.from_agent_task_results(instance, errand_name, agent_run_errand_result, nil)
        }.to_not raise_error
      end

      it 'does not pass through unexpected fields in the errand result' do
        errand_result_with_extras = agent_run_errand_result.dup
        errand_result_with_extras['unexpected-key'] = 'extra-value'

        subject = described_class.from_agent_task_results(
          instance,
          errand_name,
          errand_result_with_extras,
          'fake-logs-blobstore-id',
          'fake-blob-sha1',
        )

        expect(subject.to_hash).to eq(
          'instance' => {
            'group' => 'instance-group',
            'id' => 'dead-beef',
          },
          'errand_name' => 'errand-name',
          'exit_code' => 123,
          'stdout' => 'fake-stdout',
          'stderr' => 'fake-stderr',
          'logs' => {
            'blobstore_id' => 'fake-logs-blobstore-id',
            'sha1' => 'fake-blob-sha1'
          },
        )
      end
    end

    describe '#to_hash' do
      it 'returns blobstore_id and sha1 when it is available' do
        subject = described_class.new(instance, 'errand-name', 0, 'fake-stdout', 'fake-stderr', 'fake-blobstore-id', 'sha1-blob')
        expect(subject.to_hash).to eq(
          'instance' => {
            'group' => 'instance-group',
            'id' => 'dead-beef',
          },
          'errand_name' => 'errand-name',
          'exit_code' => 0,
          'stdout' => 'fake-stdout',
          'stderr' => 'fake-stderr',
          'logs' => {
            'blobstore_id' => 'fake-blobstore-id',
            'sha1' => 'sha1-blob',
          },
        )
      end

      it 'returns blobstore_id and sha1 as nil when it is not available' do
        subject = described_class.new(instance, 'errand-name', 0, 'fake-stdout', 'fake-stderr', nil, nil)
        expect(subject.to_hash).to eq(
          'instance' => {
            'group' => 'instance-group',
            'id' => 'dead-beef',
          },
          'errand_name' => 'errand-name',
          'exit_code' => 0,
          'stdout' => 'fake-stdout',
          'stderr' => 'fake-stderr',
          'logs' => {
            'blobstore_id' => nil,
            'sha1' => nil,
          },
        )
      end
    end

    describe '#successful?' do
      context 'when exit_code is 0' do
        it 'returns true' do
          subject = described_class.new(instance, 'errand-name', 0, 'fake-stdout', 'fake-stderr', nil, nil)
          expect(subject.successful?).to eq(true)
        end
      end

      context 'when exit code is not 0' do
        it 'returns false' do
          subject = described_class.new(instance, 'errand-name', 1, 'fake-stdout', 'fake-stderr', nil, nil)
          expect(subject.successful?).to eq(false)
        end
      end
    end

    describe '#errored?' do
      context 'when exit_code is between 1 - 128 inclusive' do
        it 'returns true' do
          subject = described_class.new(instance, 'errand-name', 1, 'fake-stdout', 'fake-stderr', nil, nil)
          expect(subject.errored?).to eq(true)
          subject = described_class.new(instance, 'errand-name', 128, 'fake-stdout', 'fake-stderr', nil, nil)
          expect(subject.errored?).to eq(true)
        end
      end

      context 'when exit code is not 1 - 128 inclusive' do
        it 'returns false' do
          subject = described_class.new(instance, 'errand-name', -1, 'fake-stdout', 'fake-stderr', nil, nil)
          expect(subject.errored?).to eq(false)
          subject = described_class.new(instance, 'errand-name', 0, 'fake-stdout', 'fake-stderr', nil, nil)
          expect(subject.errored?).to eq(false)
          subject = described_class.new(instance, 'errand-name', 129, 'fake-stdout', 'fake-stderr', nil, nil)
          expect(subject.errored?).to eq(false)
        end
      end
    end

    describe '#cancelled?' do
      context 'when exit_code is 129 or above' do
        it 'returns true' do
          subject = described_class.new(instance, 'errand-name', 129, 'fake-stdout', 'fake-stderr', nil, nil)
          expect(subject.cancelled?).to eq(true)
        end
      end

      context 'when exit code is below 129, but above -1' do
        it 'returns false' do
          subject = described_class.new(instance, 'errand-name', 0, 'fake-stdout', 'fake-stderr', nil, nil)
          expect(subject.cancelled?).to eq(false)
          subject = described_class.new(instance, 'errand-name', 128, 'fake-stdout', 'fake-stderr', nil, nil)
          expect(subject.cancelled?).to eq(false)
        end
      end
    end
  end
end
