require 'spec_helper'

module Bosh::Director
  describe OrphanNetworkManager do
    subject(:network_manager) { OrphanNetworkManager.new(logger) }

    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
    let(:cloud_factory) { instance_double(CloudFactory) }

    let(:deployment) { FactoryBot.create(:models_deployment, name: 'test-deployment') }

    let(:network) do
      FactoryBot.create(:models_network,
        name: 'dummy-network',
        type: 'manual',
        orphaned: false,
      )
    end

    let(:event_manager) { Api::EventManager.new(true) }
    let(:task) { FactoryBot.create(:models_task, id: 42, username: 'user') }

    let(:cleanup_job) do
      instance_double(Bosh::Director::Jobs::CleanupArtifacts, username: 'user', task_id: task.id, event_manager: event_manager)
    end

    before { allow(Config).to receive(:current_job).and_return(cleanup_job) }

    describe '#orphan_network' do
      it 'orphans network' do
        network_manager.orphan_network(network)
        orphan_network = Models::Network.first

        expect(orphan_network.name).to eq('dummy-network')
        expect(orphan_network.type).to eq('manual')
        expect(orphan_network.created_at).to be_truthy
        expect(orphan_network.orphaned).to eq(true)
        expect(orphan_network.orphaned_at).to be_truthy
      end
    end

    describe '#unorphan_network' do
      let(:orphan_network) do
        FactoryBot.create(:models_network,
          name: 'dummy-network',
          type: 'manual',
          orphaned: true,
          orphaned_at: Time.now,
        )
      end

      it 'unorphans network' do
        network_manager.unorphan_network(orphan_network)
        network = Models::Network.first

        expect(network.name).to eq('dummy-network')
        expect(network.type).to eq('manual')
        expect(network.created_at).to be_truthy
        expect(network.orphaned).to eq(false)
      end
    end

    describe '#list_orphan_networks' do
      it 'returns an array of orphaned networks as hashes' do
        created_at = Time.now.utc - 10
        orphaned_at = Time.now.utc
        other_orphaned_at = Time.now.utc
        FactoryBot.create(:models_network,
          name: 'dummy-network-1',
          type: 'manual',
          created_at: created_at,
          orphaned: true,
          orphaned_at: orphaned_at,
        )
        FactoryBot.create(:models_network,
          name: 'dummy-network-2',
          type: 'manual',
          created_at: created_at,
          orphaned: true,
          orphaned_at: other_orphaned_at,
        )

        expect(subject.list_orphan_networks).to eq(
          [
            {
              'name' => 'dummy-network-1',
              'type' => 'manual',
              'created_at' => created_at.to_s,
              'orphaned_at' => orphaned_at.to_s,
            },
            {
              'name' => 'dummy-network-2',
              'type' => 'manual',
              'created_at' => created_at.to_s,
              'orphaned_at' => other_orphaned_at.to_s,
            },
          ],
        )
      end
    end

    describe 'Deleting orphans' do
      let(:time) { Time.now.utc }
      let(:ten_seconds_ago) { time - 10 }
      let(:event_log) { instance_double(EventLog::Log) }
      let(:stage) { instance_double(EventLog::Stage) }

      let(:orphan_network_1) do
        FactoryBot.create(:models_network, name: 'network-1', created_at: ten_seconds_ago, orphaned: true, orphaned_at: time)
      end

      let(:subnet_1) do
        FactoryBot.create(:models_subnet,
          cid: '12345',
          name: 'subnet-1',
          range: '192.168.10.0/24',
          gateway: '192.168.10.1',
          cpi: '',
          network: orphan_network_1,
        )
      end

      let(:subnet_2) do
        FactoryBot.create(:models_subnet,
          cid: '67890',
          name: 'subnet-2',
          range: '192.168.20.0/24',
          gateway: '192.168.20.1',
          cpi: '',
          network: orphan_network_1,
        )
      end

      before do
        allow(CloudFactory).to receive(:create).and_return(cloud_factory)
        allow(cloud).to receive(:delete_network).and_return(nil)
        allow(orphan_network_1).to receive(:subnets).and_return([subnet_1, subnet_2])
      end

      describe 'deleting an orphan network' do
        it 'deletes network from the cloud and from the db' do
          expect(cloud).to receive(:delete_network).with('12345')
          expect(cloud).to receive(:delete_network).with('67890')
          expect(cloud_factory).to receive(:get).twice.and_return(cloud)
          subject.delete_network('network-1')

          expect(Models::Network.where(name: 'network-1').all).to be_empty
          expect(Models::Subnet.where(name: 'subnet-1').all).to be_empty
          expect(Models::Subnet.where(name: 'subnet-2').all).to be_empty
        end

        it 'deletes network only if the network exists in the db' do
          expect(cloud).not_to receive(:delete_network)
          expect(cloud).not_to receive(:delete_network)
          expect(cloud_factory).not_to receive(:get)
          subject.delete_network('network-2')

          expect(Models::Network.where(name: 'network-1').all).not_to be_empty
          expect(Models::Subnet.where(name: 'subnet-1').all).not_to be_empty
          expect(Models::Subnet.where(name: 'subnet-2').all).not_to be_empty
        end
      end
    end
  end
end
