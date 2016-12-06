require 'spec_helper'
require 'bosh/director/log_bundles_cleaner'

module Bosh::Director
  describe Jobs::FetchLogs do
    subject(:fetch_logs) { Jobs::FetchLogs.new(instance.id, blobstore: blobstore, 'filters' => 'filter1,filter2') }
    let(:blobstore) { instance_double('Bosh::Blobstore::BaseClient') }

    describe 'DJ job class expectations' do
      let(:job_type) { :fetch_logs }
      let(:queue) { :normal }
      it_behaves_like 'a DJ job'
    end

    describe '#perform' do
      let(:instance) { Models::Instance.make(deployment: deployment, vm_cid: nil, job: 'fake-job-name', index: '42') }
      let(:deployment) { Models::Deployment.make }

      context 'when instance is associated with a vm' do
        before { instance.update(vm_cid: 'vm-1') }

        before { allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with(instance.credentials, instance.agent_id).and_return(agent) }
        let(:agent) { instance_double('Bosh::Director::AgentClient', fetch_logs: {'blobstore_id' => 'new-fake-blobstore-id'}) }

        it 'cleans old log bundles' do
          old_log_bundle = Models::LogBundle.make(timestamp: Time.now - 12*24*60*60, blobstore_id: 'previous-fake-blobstore-id') # 12 days
          expect(blobstore).to receive(:delete).with('previous-fake-blobstore-id')

          fetch_logs.perform

          expect(Models::LogBundle.all).not_to include old_log_bundle
        end

        context 'when deleting blob from blobstore fails' do
          it 'cleans the old log bundle if it was not found in the blobstore' do
            old_log_bundle = Models::LogBundle.make(timestamp: Time.now - 12*24*60*60, blobstore_id: 'previous-fake-blobstore-id') # 12 days
            expect(blobstore).to receive(:delete).with('previous-fake-blobstore-id').and_raise(Bosh::Blobstore::NotFound)

            fetch_logs.perform

            expect(Models::LogBundle.all).not_to include old_log_bundle
          end

          it 'does not clean the old log bundle if any other error is returned' do
            old_log_bundle = Models::LogBundle.make(timestamp: Time.now - 12*24*60*60, blobstore_id: 'previous-fake-blobstore-id') # 12 days
            expect(blobstore).to receive(:delete).with('previous-fake-blobstore-id').and_raise(Bosh::Blobstore::NotImplemented)

            fetch_logs.perform

            new_log_bundle = Models::LogBundle.first(blobstore_id: 'new-fake-blobstore-id')
            expect(Models::LogBundle.all).to eq [old_log_bundle, new_log_bundle]
          end
        end

        context 'when agent returns blobstore id in its response to fetch_logs' do
          it 'asks agent to fetch logs and returns blobstore id' do
            expect(agent).to receive(:fetch_logs).
              with('job', 'filter1,filter2').
              and_return('blobstore_id' => 'fake-blobstore-id')

            expect(fetch_logs.perform).to eq('fake-blobstore-id')
          end

          it 'registers returned blobstore id as a log bundle' do
            expect(Models::LogBundle.all).to be_empty

            fetch_logs.perform
            expect(Models::LogBundle.where(blobstore_id: 'new-fake-blobstore-id')).not_to be_empty
          end
        end

        context 'when agent does not return blobstore id in its response to fetch_logs' do
          before { allow(agent).to receive(:fetch_logs).and_return({}) }

          it 'raises an exception' do
            expect {
              fetch_logs.perform
            }.to raise_error(AgentTaskNoBlobstoreId, "Agent didn't return a blobstore object id for packaged logs")
          end

          it 'does not register non-existent blobstore id as a log bundle' do
            expect(Models::LogBundle.all).to be_empty

            expect { fetch_logs.perform }.to raise_error

            expect(Models::LogBundle.all).to be_empty
          end
        end
      end

      context 'when instance is not associated with a vm' do
        it 'raises an exception because there is no agent to contact' do
          expect {
            fetch_logs.perform
          }.to raise_error(InstanceVmMissing, "'fake-job-name/#{instance.uuid} (42)' doesn't reference a VM")
        end
      end
    end
  end
end
