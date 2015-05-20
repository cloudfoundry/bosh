require 'spec_helper'

module VSphereCloud
  describe DiskProvider do
    subject(:disk_provider) do
      described_class.new(
        virtual_disk_manager,
        datacenter,
        resources,
        'fake-disk-path',
        client,
        logger
      )
    end

    let(:virtual_disk_manager) { instance_double('VimSdk::Vim::VirtualDiskManager') }
    let(:datacenter) do
      instance_double('VSphereCloud::Resources::Datacenter', name: 'fake-datacenter-name', mob: datacenter_mob)
    end
    let(:datacenter_mob) { instance_double('VimSdk::Vim::Datacenter') }
    let(:resources) { instance_double('VSphereCloud::Resources') }
    let(:client) { instance_double('VSphereCloud::Client', wait_for_task: nil) }
    let(:logger) { double(:logger, info: nil, debug: nil) }

    let(:datastore) { Resources::Datastore.new('fake-datastore', 'mob', 2048, 1024) }
    let(:disk) { Resources::Disk.new('disk-cid', 24, datastore, 'fake-disk-path') }

    describe '#create' do
      before do
        allow(SecureRandom).to receive(:uuid).and_return('cid')
        allow(virtual_disk_manager).to receive(:create_virtual_disk)
      end

      let(:datastore) { instance_double('VSphereCloud::Resources::Datastore', name: 'fake-datastore-name') }

      context 'when cluster is nil' do
        it 'creates disk using VirtualDiskManager' do
          expect(datacenter).to receive(:pick_persistent_datastore).with(24).and_return(datastore)

          expect(client).to receive(:create_disk)
                              .with(datacenter, datastore, 'disk-cid', 'fake-disk-path', 24)
                              .and_return(disk)
          expect(disk_provider.create(24, nil)).to eq(disk)
        end
      end

      context 'when cluster is provided' do
        it 'creates disk in vm cluster' do
          cluster = instance_double(VSphereCloud::Resources::Cluster, name: 'fake-cluster-name')
          expect(resources).to receive(:pick_persistent_datastore_in_cluster).with('fake-cluster-name', 24).and_return(datastore)

          expect(client).to receive(:create_disk)
                              .with(datacenter, datastore, 'disk-cid', 'fake-disk-path', 24)
                              .and_return(disk)
          expect(disk_provider.create(24, cluster)).to eq(disk)
        end
      end
    end

    describe '#find_and_move' do
      let(:cluster) { instance_double('VSphereCloud::Resources::Cluster', name: 'fake-cluster-name') }

      context 'when disk exists' do
        context 'when disk is in one of accessible datastores' do
          let(:datastore) { instance_double('VSphereCloud::Resources::Datastore', name: 'fake-datastore') }
          let(:accessible_datastores) { [datastore.name] }
          let(:disk) { Resources::Disk.new('disk-cid',0, datastore, "[data-store-name] fake-disk-path/disk-cid.vmdk") }
          before do
            allow(datacenter).to receive(:persistent_datastores).and_return({'fake-datastore' => datastore})
            allow(client).to receive(:find_disk).with('disk-cid', datastore, 'fake-disk-path') { disk }
          end

          context 'when disk is in persistent datastores' do
            it 'returns disk' do
              expect(disk_provider.find_and_move('disk-cid', cluster, 'fake-datacenter', accessible_datastores)).
                to eq(disk)
            end
          end
        end

        context 'when disk is not in one of the accessible datastores' do
          let(:destination_datastore) { instance_double('VSphereCloud::Resources::Datastore', name: 'destination-datastore') }
          let(:accessible_datastores) { [destination_datastore.name] }
          let(:inaccessible_datastore) { instance_double('VSphereCloud::Resources::Datastore', name: 'inaccessible-datastore') }
          let(:disk) { Resources::Disk.new('disk-cid',0, inaccessible_datastore, "[inaccessible-datastore] fake-disk-path/disk-cid.vmdk") }

          before do
            allow(datacenter).to receive(:persistent_datastores).and_return({'fake-datastore' => inaccessible_datastore})
            allow(resources).to receive(:pick_persistent_datastore_in_cluster).and_return(destination_datastore)
            allow(client).to receive(:find_disk).with('disk-cid', inaccessible_datastore, 'fake-disk-path') { disk }
          end

          it 'moves disk' do
            expect(client).to receive(:move_disk).with(
              'fake-host-datacenter',
              '[inaccessible-datastore] fake-disk-path/disk-cid.vmdk',
              'fake-host-datacenter',
              '[destination-datastore] fake-disk-path/disk-cid.vmdk'
            )

            disk = disk_provider.find_and_move('disk-cid', cluster, 'fake-host-datacenter', accessible_datastores)

            expect(disk.cid).to eq('disk-cid')
            expect(disk.datastore).to eq(destination_datastore)
            expect(disk.path).to eq('[destination-datastore] fake-disk-path/disk-cid.vmdk')
          end



          context 'when picked datastore is not one of the accessible datastores' do
            let(:accessible_datastores) { ['not-the-destination-datastore'] }

            it 'raises an error' do
              expect {
                disk_provider.find_and_move('disk-cid', cluster, 'fake-host-datacenter', accessible_datastores)
              }.to raise_error "Datastore 'destination-datastore' is not accessible to cluster 'fake-cluster-name'"
            end
          end
        end
      end

      context 'when disk does not exist' do
        before do
          allow(datacenter).to receive(:persistent_datastores).and_return({})
        end

        it 'raises DiskNotFound' do
          expect {
            disk_provider.find_and_move('disk-cid', cluster, 'fake-datacenter', ['fake-datastore'])
          }.to raise_error Bosh::Clouds::DiskNotFound
        end
      end
    end

    describe '#find' do
      let(:first_datastore) { instance_double(Resources::Datastore) }
      let(:second_datastore) { instance_double(Resources::Datastore) }

      before do
        allow(datacenter).to receive(:persistent_datastores).and_return({
              'datastore-without-disk' => first_datastore,
              'datastore-with-disk' => second_datastore,
            })
      end

      context 'when disk exists' do
        let(:disk) { Resources::Disk.new('disk-cid', 1024, datastore, "[data-store-name] fake-disk-path/disk-cid.vmdk") }
        before do
          allow(client).to receive(:find_disk).with('disk-cid', first_datastore, 'fake-disk-path') { nil }
          allow(client).to receive(:find_disk).with('disk-cid', second_datastore, 'fake-disk-path') { disk }
        end

        it 'returns disk' do
          expect(disk_provider.find('disk-cid')).to eq(disk)
        end
      end

      context 'when disk does not exist' do
        before do
          allow(client).to receive(:find_disk).with('disk-cid', first_datastore, 'fake-disk-path') { nil }
          allow(client).to receive(:find_disk).with('disk-cid', second_datastore, 'fake-disk-path') { nil }
        end

        it 'raises DiskNotFound' do
          expect {
            disk_provider.find('disk-cid')
          }.to raise_error{ |error|
              expect(error).to be_a(Bosh::Clouds::DiskNotFound)
              expect(error.ok_to_retry).to eq(false)
              expect(error.message).to  match(/Could not find disk with id 'disk-cid'/)
            }
        end
      end
    end
  end
end
