require 'spec_helper'
require 'bosh/director/logs_fetcher'
require 'logger'

module Bosh::Director
  describe LogsFetcher do
    subject { described_class.new(instance_manager, log_bundles_cleaner, log) }

    let(:instance_manager) { instance_double(Bosh::Director::Api::InstanceManager) }
    let(:log_bundles_cleaner) { instance_double(Bosh::Director::LogBundlesCleaner) }
    let(:mock_instance_model) do
      instance_double(Bosh::Director::Models::Instance,
      job: 'some-job',
      uuid: 'some-uuid',
      index: 'some-index')
    end
    let(:filters) do
      filters = double 'filters'
      allow(filters).to receive(:to_s).and_return 'some-filters'
      filters
    end
    let(:log) { double('logger') }

    describe '#fetch' do
      let(:mock_agent) do
        instance_double(Bosh::Director::AgentClient)
      end

      context 'after successfully logging and cleaning bundles' do
        before do
          expect(log).to receive(:info).with(match /some-log-type.*some-filters/)
          expect(log_bundles_cleaner).to receive(:clean)
          expect(instance_manager).
            to receive(:agent_client_for).
            with(mock_instance_model).
            and_return mock_agent
        end

        context 'when the agent finds logs for that type and filters' do
          it 'returns the blobstore ID' do
            expect(mock_agent).to receive(:fetch_logs).and_return({
              'blobstore_id' => 'blobid1'
            })

            blob, sha = subject.fetch(mock_instance_model, 'some-log-type', filters)
            expect(blob).to eq 'blobid1'
            expect(sha).to be_nil
          end

          it 'returns the sha as well if the agent provides one' do
            expect(mock_agent).to receive(:fetch_logs).and_return({
              'blobstore_id' => 'blobid1',
              'sha1' => 'sha1-digest'
            })

            blob, sha = subject.fetch(mock_instance_model, 'some-log-type', filters)
            expect(blob).to eq 'blobid1'
            expect(sha).to eq 'sha1-digest'
          end

          it 'registers the blob with the cleaner when marked persistent' do
            expect(mock_agent).to receive(:fetch_logs).and_return({
              'blobstore_id' => 'blobid1'
            })

            expect(log_bundles_cleaner).to receive(:register_blobstore_id).with('blobid1')

            subject.fetch(mock_instance_model, 'some-log-type', filters, true)
          end
        end

        context 'when the agent does not find the logs' do
          it 'raises an error' do
            expect(mock_agent).to receive(:fetch_logs).and_return({
              'blobstore_id' => nil
            })

            expect {
              subject.fetch(mock_instance_model, 'some-log-type', filters)
            }.to raise_error AgentTaskNoBlobstoreId
          end
        end
      end
    end
  end
end