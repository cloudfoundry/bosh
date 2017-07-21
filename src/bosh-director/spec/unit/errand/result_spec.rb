require 'spec_helper'

module Bosh::Director
  describe Errand::Result do
    describe '.from_agent_task_result' do
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
            described_class.from_agent_task_results(invalid_errand_result, nil)
          }.to raise_error(AgentInvalidTaskResult, /#{field_name}.*missing/i)
        end
      end

      it 'does not raise an error if fetch_logs results is nil (not available)' do
        expect {
          described_class.from_agent_task_results(agent_run_errand_result, nil)
        }.to_not raise_error
      end

      it 'does not pass through unexpected fields in the errand result' do
        errand_result_with_extras = agent_run_errand_result.dup
        errand_result_with_extras['unexpected-key'] = 'extra-value'

        subject = described_class.from_agent_task_results(
          errand_result_with_extras,
          'fake-logs-blobstore-id',
          'fake-blob-sha1',
        )

        expect(subject.to_hash).to eq(
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

    describe '#short_description' do
      context 'when errand exit_code is 0' do
        it 'returns successful errand completion message as task short result (not result file)' do
          subject = described_class.new(0, '', '', '')
          expect(subject.short_description('fake-job-name')).to eq(
            "Errand 'fake-job-name' completed successfully (exit code 0)")
        end
      end

      context 'when errand exit_code is non-0' do
        it 'returns error errand completion message as task short result (not result file)' do
          subject = described_class.new(123, '', '', '')
          expect(subject.short_description('fake-job-name')).to eq(
            "Errand 'fake-job-name' completed with error (exit code 123)")
        end
      end

      context 'when errand exit_code is >128' do
        it 'returns error errand cancellation message as task short result (not result file)' do
          subject = described_class.new(143, '', '', '')
          expect(subject.short_description('fake-job-name')).to eq(
            "Errand 'fake-job-name' was canceled (exit code 143)")
        end
      end
    end

    describe '#to_hash' do
      it 'returns blobstore_id and sha1 when it is available' do
        subject = described_class.new(0, 'fake-stdout', 'fake-stderr', 'fake-blobstore-id', 'sha1-blob')
        expect(subject.to_hash).to eq(
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
        subject = described_class.new(0, 'fake-stdout', 'fake-stderr', nil, nil)
        expect(subject.to_hash).to eq(
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
  end
end
