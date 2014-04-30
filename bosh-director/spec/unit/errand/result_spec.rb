require 'spec_helper'

module Bosh::Director
  describe Errand::Result do
    describe '.from_agent_task_result' do
      let(:errand_result) do
        {
          'exit_code' => 123,
          'stdout' => 'fake-stdout',
          'stderr' => 'fake-stderr',
        }
      end

      %w(exit_code stdout stderr).each do |field_name|
        it "raises an error when #{field_name} is missing in the errand result" do
          invalid_errand_result = errand_result.reject { |k, _| k == field_name }
          expect {
            described_class.from_agent_task_result(invalid_errand_result)
          }.to raise_error(AgentInvalidTaskResult, /#{field_name}.*missing/i)
        end
      end

      it 'does not pass through unexpected fields in the errand result' do
        errand_result_with_extras = errand_result.dup
        errand_result_with_extras['unexpected-key'] = 'extra-value'
        subject = described_class.from_agent_task_result(errand_result_with_extras)
        expect(subject.to_hash).to eq(errand_result)
      end
    end

    describe '#short_description' do
      context 'when errand exit_code is 0' do
        it 'returns successful errand completion message as task short result (not result file)' do
          subject = described_class.new(0, 'fake-stdout', 'fake-stderr')
          expect(subject.short_description('fake-job-name')).to eq(
            'Errand `fake-job-name\' completed successfully (exit code 0)')
        end
      end

      context 'when errand exit_code is non-0' do
        it 'returns error errand completion message as task short result (not result file)' do
          subject = described_class.new(123, 'fake-stdout', 'fake-stderr')
          expect(subject.short_description('fake-job-name')).to eq(
            'Errand `fake-job-name\' completed with error (exit code 123)')
        end
      end

      context 'when errand exit_code is >128' do
        it 'returns error errand cancellation message as task short result (not result file)' do
          subject = described_class.new(143, 'fake-stdout', 'fake-stderr')
          expect(subject.short_description('fake-job-name')).to eq(
            'Errand `fake-job-name\' was canceled (exit code 143)')
        end
      end
    end
  end
end
