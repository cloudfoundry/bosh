require 'spec_helper'

describe Bosh::Cli::Client::ErrandsClient do
  subject(:client) { described_class.new(director) }
  let(:director) { instance_double('Bosh::Cli::Client::Director') }

  describe '#run_errand' do
    it 'tells director to run errand that is part of a deployment' do
      allow(director).to receive(:get_task_result_log).and_return('{}')

      expect(director).to receive(:request_and_track)
        .with(
          :post,
          '/deployments/fake-deployment-name/errands/fake-errand-name/runs',
          { content_type: 'application/json', payload: "{\"keep-alive\":false}" },
        )
        .and_return([:done, 'fake-task-id'])

      client.run_errand('fake-deployment-name', 'fake-errand-name', FALSE)
    end

    it 'tells the director to run the errand with the keep-alive option' do
      allow(director).to receive(:get_task_result_log).and_return('{}')

      expect(director).to receive(:request_and_track)
      .with(
        :post,
        '/deployments/fake-deployment-name/errands/fake-errand-name/runs',
        { content_type: 'application/json', payload: "{\"keep-alive\":true}" },
      )
      .and_return([:done, 'fake-task-id'])

      client.run_errand('fake-deployment-name', 'fake-errand-name', TRUE)
    end

    [:done, :cancelled].each do |status|
      context "when task status is #{status}" do
        before { allow(director).to receive(:request_and_track).and_return([status, 'fake-task-id']) }

        it 'fetches the output for the task and return an errand result' do
          raw_task_output = JSON.dump(
            exit_code: 123,
            stdout: 'fake-stdout',
            stderr: 'fake-stderr',
            logs: {blobstore_id: 'fake-logs-blobstore-id'},
          )

          expect(director).to receive(:get_task_result_log).
            with('fake-task-id').
            and_return("#{raw_task_output}\n")

          actual_status, task_id, actual_result = client.run_errand('fake-deployment-name', 'fake-errand-name', FALSE)
          expect(actual_status).to eq(status)
          expect(task_id).to eq('fake-task-id')
          expect(actual_result).to eq(described_class::ErrandResult.new(
            123, 'fake-stdout', 'fake-stderr', 'fake-logs-blobstore-id'))
        end

        it 'does not set logs_blobstore_id if director does not include return logs key (older directors)' do
          raw_task_output = JSON.dump(
            exit_code: 123,
            stdout: 'fake-stdout',
            stderr: 'fake-stderr',
            # no logs key
          )

          expect(director).to receive(:get_task_result_log).
            with('fake-task-id').
            and_return("#{raw_task_output}\n")

          actual_status, task_id, actual_result = client.run_errand('fake-deployment-name', 'fake-errand-name', FALSE)
          expect(actual_status).to eq(status)
          expect(task_id).to eq('fake-task-id')
          expect(actual_result).to eq(described_class::ErrandResult.new(
            123, 'fake-stdout', 'fake-stderr', nil))
        end

        it 'does not raise an error if output is empty' do
          expect(director).to receive(:get_task_result_log).with('fake-task-id').and_return(nil)

          actual_status, task_id, actual_result = client.run_errand('fake-deployment-name', 'fake-errand-name', FALSE)
          expect(actual_status).to eq(status)
          expect(task_id).to eq('fake-task-id')
          expect(actual_result).to be_nil
        end
      end
    end

    context 'when task status is not :done or :cancelled (e.g. error, etc)' do
      before { allow(director).to receive(:request_and_track).and_return([:not_done, 'fake-task-id']) }

      it 'returns status, task_id and result' do
        status, task_id, result = client.run_errand('fake-deployment-name', 'fake-errand-name', FALSE)
        expect(status).to eq(:not_done)
        expect(task_id).to eq('fake-task-id')
        expect(result).to be_nil
      end
    end
  end
end
