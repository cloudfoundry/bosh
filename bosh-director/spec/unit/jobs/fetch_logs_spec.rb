require 'spec_helper'
require 'bosh/director/log_bundles_cleaner'

module Bosh::Director
  describe Jobs::FetchLogs do
    subject(:fetch_logs) { Jobs::FetchLogs.new(instance.id, blobstore: blobstore, 'filters' => 'filter1,filter2') }
    let(:blobstore) { instance_double('Bosh::Blobstore::BaseClient') }

    before { allow(LogBundlesCleaner).to receive(:new).and_return(log_bundles_cleaner) }
    let(:log_bundles_cleaner) do
      instance_double('Bosh::Director::LogBundlesCleaner', {
        register_blobstore_id: nil,
        clean: nil,
      })
    end

    describe 'Resque job class expectations' do
      let(:job_type) { :fetch_logs }
      it_behaves_like 'a Resque job'
    end

    describe '#perform' do
      before { allow(fetch_logs).to receive(:with_deployment_lock).and_yield }

      let(:instance) { Models::Instance.make(deployment: deployment, vm: nil, job: 'fake-job-name', index: '42') }
      let(:deployment) { Models::Deployment.make }

      context 'when instance is associated with a vm' do
        before { instance.update(vm: vm) }
        let(:vm) { Models::Vm.make(deployment: deployment, agent_id: 'fake-agent-id', cid: 'vm-1') }

        before { allow(AgentClient).to receive(:with_defaults).with('fake-agent-id').and_return(agent) }
        let(:agent) { instance_double('Bosh::Director::AgentClient', fetch_logs: {'blobstore_id' => 'fake-blobstore-id'}) }

        it 'cleans old log bundles' do
          expect(log_bundles_cleaner).to receive(:clean).with(no_args)
          fetch_logs.perform
        end

        context 'when agent returns blobstore id in its response to fetch_logs' do
          it 'asks agent to fetch logs and returns blobstore id' do
            expect(agent).to receive(:fetch_logs).
              with('job', 'filter1,filter2').
              and_return('blobstore_id' => 'fake-blobstore-id')

            expect(fetch_logs.perform).to eq('fake-blobstore-id')
          end

          it 'registers returned blobstore id as a log bundle' do
            expect(log_bundles_cleaner).to receive(:register_blobstore_id).with('fake-blobstore-id')
            fetch_logs.perform
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
            expect(log_bundles_cleaner).to_not receive(:register_blobstore_id)
            expect { fetch_logs.perform }.to raise_error
          end
        end
      end

      context 'when instance is not associated with a vm' do
        it 'raises an exception because there is no agent to contact' do
          expect {
            fetch_logs.perform
          }.to raise_error(InstanceVmMissing, "`fake-job-name/42' doesn't reference a VM")
        end
      end
    end
  end
end
