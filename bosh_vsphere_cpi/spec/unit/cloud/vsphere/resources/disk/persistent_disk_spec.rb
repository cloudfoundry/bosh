require 'spec_helper'

module VSphereCloud
  describe PersistentDisk do
    subject(:persistent_disk) { PersistentDisk.new('fake-disk-cid', cloud_searcher, resources, client, logger) }

    let(:cloud_searcher) { instance_double('VSphereCloud::CloudSearcher') }
    let(:resources) do
      instance_double('VSphereCloud::Resources',
        datacenters: {
          'fake-folder/fake-datacenter-name' => datacenter,
          'fake-incorrect-datacenter-name' => incorrect_datacenter,
        }
      )
    end
    let(:client) { instance_double('VSphereCloud::Client', create_datastore_folder: nil) }
    let(:logger) { instance_double('Logger', info: nil, debug: nil) }

    let(:datacenter) { instance_double('VSphereCloud::Resources::Datacenter', disk_path: 'fake-disk-path', name: 'fake-folder/fake-datacenter-name', mob: 'datacenter-mob') }
    before { allow(client).to receive(:find_by_inventory_path).with('fake-folder/fake-datacenter-name').and_return(datacenter) }

    let(:incorrect_datacenter) { instance_double('VSphereCloud::Resources::Datacenter', disk_path: 'fake-disk-path', mob: 'incorrect-datacenter-mob') }

    after do
      disk = Models::Disk.find(uuid: 'fake-disk-cid')
      disk.delete if disk
    end

    describe '#create_spec' do
      let(:host_info) do
        {
          'cluster' => 'fake-cluster-name',
          'datastores' => ['fake-datastore-name', 'fake-datastore-name-2'],
          'datacenter' => datacenter
        }
      end
      let(:controller_key) { double(:controller_key) }

      let(:datastore) { instance_double('VSphereCloud::Resources::Datastore', mob: nil, name: 'fake-datastore-name') }
      before do
        allow(resources).to receive(:place_persistent_datastore).and_return(datastore)
        allow(resources).to receive(:persistent_datastore).and_return(datastore)
      end

      context 'when disk exists in database' do
        context 'when disk does not exist (path is not set)' do
          before do
            Models::Disk.new(uuid: 'fake-disk-cid', size: 1024).save
          end

          it 'creates a disk' do
            spec = persistent_disk.create_spec('fake-folder/fake-datacenter-name', host_info, controller_key, true)

            expect(spec.file_operation).to eq(VimSdk::Vim::Vm::Device::VirtualDeviceSpec::FileOperation::CREATE)
            expect(spec.operation).to eq(VimSdk::Vim::Vm::Device::VirtualDeviceSpec::Operation::ADD)
            expect(spec.device.controller_key).to eq(controller_key)
            expect(spec.device.capacity_in_kb).to eq(1024)
            expect(spec.device.backing.file_name).to eq('[fake-datastore-name] fake-disk-path/fake-disk-cid.vmdk')
            expect(spec.device.backing.datastore).to eq(datastore)
            expect(spec.device.backing.disk_mode).to eq(VimSdk::Vim::Vm::Device::VirtualDiskOption::DiskMode::INDEPENDENT_PERSISTENT)

            disk = Models::Disk.first(uuid: 'fake-disk-cid')
            expect(disk.datacenter).to eq('fake-folder/fake-datacenter-name')
            expect(disk.datastore).to eq('fake-datastore-name')
            expect(disk.path).to eq('[fake-datastore-name] fake-disk-path/fake-disk-cid')
          end

          it 'creates disk folder in datastore' do
            expect(client).to receive(:create_datastore_folder).with('[fake-datastore-name] fake-disk-path', datacenter.mob)
            persistent_disk.create_spec('fake-folder/fake-datacenter-name', host_info, controller_key, true)
          end
        end

        context 'when disk already exists (path is set)' do
          before do
            Models::Disk.new(
              uuid: 'fake-disk-cid',
              size: 1024,
              path: '[fake-datastore-name] fake-disk-path/fake-disk-cid',
              datastore: 'fake-datastore-name',
            ).save
          end

          shared_examples :moves_or_creates_disk do
            before do
              allow(client).to receive(:find_by_inventory_path).with(disk_datacenter_name).and_return(source_datacenter)
            end

            context 'when it is configured to copy disk' do
              let(:copy_disks) { true }

              it 'copies the disk' do
                expect(client).to receive(:copy_disk).with(
                  source_datacenter,
                  "[#{source_datastore_name}] fake-disk-path/fake-disk-cid",
                  datacenter,
                  '[fake-datastore-name] fake-disk-path/fake-disk-cid',
                )

                spec = persistent_disk.create_spec('fake-folder/fake-datacenter-name', host_info, controller_key, copy_disks)
                expect(spec.file_operation).to be_nil
              end

              it 'creates disk folder in datastore' do
                expect(client).to receive(:copy_disk)
                expect(client).to receive(:create_datastore_folder).with('[fake-datastore-name] fake-disk-path', datacenter.mob)
                persistent_disk.create_spec('fake-folder/fake-datacenter-name', host_info, controller_key, copy_disks)
              end
            end

            context 'when it is configured to move disk' do
              let(:copy_disks) { false }

              it 'moves the disk' do
                expect(client).to receive(:move_disk).with(
                  source_datacenter,
                  "[#{source_datastore_name}] fake-disk-path/fake-disk-cid",
                  datacenter,
                  '[fake-datastore-name] fake-disk-path/fake-disk-cid',
                )

                spec = persistent_disk.create_spec('fake-folder/fake-datacenter-name', host_info, controller_key, copy_disks)
                expect(spec.file_operation).to be_nil
              end

              it 'creates disk folder in datastore' do
                expect(client).to receive(:move_disk)
                expect(client).to receive(:create_datastore_folder).with('[fake-datastore-name] fake-disk-path', datacenter.mob)
                persistent_disk.create_spec('fake-folder/fake-datacenter-name', host_info, controller_key, copy_disks)
              end
            end
          end

          context 'when disk is in correct datacenter' do
            let(:disk_datacenter_name) { 'fake-folder/fake-datacenter-name' }
            let(:source_datacenter) { datacenter }
            let(:source_datastore_name) { 'fake-datastore-name' }

            before do
              disk = Models::Disk.first(uuid: 'fake-disk-cid')
              disk.datacenter = disk_datacenter_name
              disk.save
            end

            context 'when persistent datastore is valid' do
              before do
                allow(resources).to receive(:validate_persistent_datastore).and_return(true)
              end

              it 'does not create the disk' do
                expect(client).not_to receive(:move_disk)
                expect(client).not_to receive(:copy_disk)

                spec = persistent_disk.create_spec('fake-folder/fake-datacenter-name', host_info, controller_key, true)

                expect(spec.file_operation).to be_nil
                expect(spec.operation).to eq(VimSdk::Vim::Vm::Device::VirtualDeviceSpec::Operation::ADD)
                expect(spec.device.controller_key).to eq(controller_key)
                expect(spec.device.capacity_in_kb).to eq(1024)
                expect(spec.device.backing.file_name).to eq('[fake-datastore-name] fake-disk-path/fake-disk-cid.vmdk')
                expect(spec.device.backing.datastore).to eq(datastore)
                expect(spec.device.backing.disk_mode).to eq(VimSdk::Vim::Vm::Device::VirtualDiskOption::DiskMode::INDEPENDENT_PERSISTENT)

                disk = Models::Disk.first(uuid: 'fake-disk-cid')
                expect(disk.datacenter).to eq('fake-folder/fake-datacenter-name')
                expect(disk.datastore).to eq('fake-datastore-name')
                expect(disk.path).to eq('[fake-datastore-name] fake-disk-path/fake-disk-cid')
              end
            end

            context 'when persistent datastore is not valid' do
              before do
                allow(resources).to receive(:validate_persistent_datastore).and_return(false)
              end

              it_behaves_like :moves_or_creates_disk
            end
          end

          context 'when disk is in incorrect datacenter' do
            let(:disk_datacenter_name) { 'fake-incorrect-datacenter-name' }
            let(:source_datacenter) { incorrect_datacenter }
            let(:source_datastore_name) { 'fake-source-datastore-name' }

            before do
              disk = Models::Disk.first(uuid: 'fake-disk-cid')
              disk.datacenter = disk_datacenter_name
              disk.path = '[fake-source-datastore-name] fake-disk-path/fake-disk-cid'
              disk.save
            end

            it_behaves_like :moves_or_creates_disk
          end
        end
      end

      context 'when disk does not exist in database' do
        it 'raises an error' do
          expect {
            persistent_disk
          }.to raise_error
        end
      end
    end
  end
end
