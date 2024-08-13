require 'spec_helper'

module Bosh::Director
  describe Jobs::DeleteOrphanNetworks do
    let(:event_manager) { Api::EventManager.new(true) }
    let(:task) { FactoryBot.create(:models_task, id: 42, username: 'user') }
    let(:delete_orphan_networks_job) { instance_double(Bosh::Director::Jobs::DeleteOrphanNetworks, username: 'user', task_id: task.id, event_manager: event_manager) }

    before { allow(Config).to receive(:current_job).and_return(delete_orphan_networks_job) }

    describe '.enqueue' do
      let(:job_queue) { instance_double(JobQueue) }

      it 'enqueues a DeleteOrphanNetworks job' do
        fake_orphan_networks_names = ['nw-1', 'nw-2']
        Models::Network.make(name: 'nw-1', orphaned: true)
        Models::Network.make(name: 'nw-2', orphaned: true)
        expect(job_queue).to receive(:enqueue)
          .with('fake-username', Jobs::DeleteOrphanNetworks, 'delete orphan networks', [fake_orphan_networks_names])
        Jobs::DeleteOrphanNetworks.enqueue('fake-username', fake_orphan_networks_names, job_queue)
      end

      it 'errors if network is not orphaned' do
        Models::Network.make(name: 'nw-2', orphaned: false)
        expect do
          Jobs::DeleteOrphanNetworks.enqueue(nil, ['nw-2'], JobQueue.new)
        end.to raise_error(NetworkDeletingUnorphanedError)
      end

      it 'errors if network doesnot exist' do
        Models::Network.make(name: 'nw-2', orphaned: false)
        expect do
          Jobs::DeleteOrphanNetworks.enqueue(nil, ['nw-4'], JobQueue.new)
        end.to raise_error(NetworkNotFoundError)
      end
    end

    describe '#perform' do
      let(:event_log) { EventLog::Log.new }
      let(:event_log_stage) { instance_double(Bosh::Director::EventLog::Stage) }
      let(:orphan_network_manager) { instance_double(OrphanNetworkManager) }

      before do
        Bosh::Director::Models::Network.make(name: 'nw-1', orphaned: true)
        Bosh::Director::Models::Network.make(name: 'nw-2', orphaned: true)

        allow(Config).to receive(:event_log).and_return(event_log)
        allow(event_log).to receive(:begin_stage).and_return(event_log_stage)
        allow(event_log_stage).to receive(:advance_and_track).and_yield

        allow(OrphanNetworkManager).to receive(:new).and_return(orphan_network_manager)
      end

      context 'when deleting a network' do
        it 'logs and returns the result' do
          expect(orphan_network_manager).to receive(:delete_network).with('nw-1')
          expect(orphan_network_manager).to receive(:delete_network).with('nw-2')

          delete_orphan_networks = Jobs::DeleteOrphanNetworks.new(['nw-1', 'nw-2'])
          delete_orphan_networks.perform
        end
      end
    end
  end
end
