require 'spec_helper'

module Bosh::Director
  describe OrphanDiskManager do
    subject(:disk_manager) { OrphanDiskManager.new(logger) }

    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
    let(:cloud_factory) { instance_double(CloudFactory) }

    let(:deployment) { FactoryBot.create(:models_deployment, name: 'test-deployment') }

    let(:instance) do
      FactoryBot.create(:models_instance, availability_zone: 'az-1', deployment: deployment, job: 'test-instance', uuid: 'test-uuid')
    end

    let(:persistent_disk) do
      FactoryBot.create(:models_persistent_disk,
        instance: instance,
        disk_cid: 'disk123',
        size: 2048,
        cloud_properties: { 'cloud' => 'properties' },
        active: true,
        cpi: 'some-cpi',
      )
    end

    let(:event_manager) { Api::EventManager.new(true) }
    let(:task) { FactoryBot.create(:models_task, id: 42, username: 'user') }

    let(:cleanup_job) do
      instance_double(Bosh::Director::Jobs::CleanupArtifacts, username: 'user', task_id: task.id, event_manager: event_manager)
    end

    before { allow(Config).to receive(:current_job).and_return(cleanup_job) }

    describe '#orphan_disk' do
      it 'orphans disks and snapshots' do
        snapshot = FactoryBot.create(:models_snapshot, persistent_disk: persistent_disk)

        disk_manager.orphan_disk(persistent_disk)
        orphan_disk = Models::OrphanDisk.first
        orphan_snapshot = Models::OrphanSnapshot.first

        expect(orphan_disk.availability_zone).to eq('az-1')
        expect(orphan_disk.cloud_properties).to eq('cloud' => 'properties')
        expect(orphan_disk.cpi).to eq('some-cpi')
        expect(orphan_disk.deployment_name).to eq('test-deployment')
        expect(orphan_disk.disk_cid).to eq(persistent_disk.disk_cid)
        expect(orphan_disk.instance_name).to eq('test-instance/test-uuid')
        expect(orphan_disk.size).to eq(2048)

        expect(orphan_snapshot.snapshot_cid).to eq(snapshot.snapshot_cid)
        expect(orphan_snapshot.orphan_disk).to eq(orphan_disk)

        expect(Models::PersistentDisk.all.count).to eq(0)
        expect(Models::Snapshot.all.count).to eq(0)
        expect(Models::Event.all.count).to eq(2)
      end

      it 'should transactionally move orphan disks and snapshots' do
        conflicting_orphan_disk = FactoryBot.create(:models_orphan_disk)
        conflicting_orphan_snapshot = FactoryBot.create(:models_orphan_snapshot,
          orphan_disk: conflicting_orphan_disk,
          snapshot_cid: 'existing_cid',
          snapshot_created_at: Time.now,
        )

        FactoryBot.create(:models_snapshot,
          snapshot_cid: 'existing_cid',
          persistent_disk: persistent_disk,
        )

        expect { disk_manager.orphan_disk(persistent_disk) }.to raise_error(Sequel::ValidationFailed)

        conflicting_orphan_snapshot.destroy
        conflicting_orphan_disk.destroy

        expect(Models::PersistentDisk.all.count).to eq(1)
        expect(Models::Snapshot.all.count).to eq(1)
        expect(Models::OrphanDisk.all.count).to eq(0)
        expect(Models::OrphanSnapshot.all.count).to eq(0)
      end

      it 'should store event' do
        FactoryBot.create(:models_snapshot, persistent_disk: persistent_disk)
        expect do
          disk_manager.orphan_disk(persistent_disk)
        end.to change { Bosh::Director::Models::Event.count }.from(0).to(2)

        event1 = Bosh::Director::Models::Event.first
        expect(event1.user).to eq(task.username)
        expect(event1.action).to eq('orphan')
        expect(event1.object_type).to eq('disk')
        expect(event1.object_name).to eq('disk123')
        expect(event1.instance).to eq("#{persistent_disk.instance.job}/#{persistent_disk.instance.uuid}")
        expect(event1.deployment).to eq(persistent_disk.instance.deployment.name)
        expect(event1.error).to be_nil
        expect(event1.task).to eq(task.id.to_s)

        event2 = Bosh::Director::Models::Event.all.last
        expect(event2.parent_id).to eq(event1.id)
        expect(event2.user).to eq(task.username)
        expect(event2.action).to eq('orphan')
        expect(event2.object_type).to eq('disk')
        expect(event2.object_name).to eq('disk123')
        expect(event2.instance).to eq("#{persistent_disk.instance.job}/#{persistent_disk.instance.uuid}")
        expect(event2.deployment).to eq(persistent_disk.instance.deployment.name)
        expect(event2.error).to be_nil
        expect(event2.task).to eq(task.id.to_s)
      end
    end

    describe '#unorphan_disk' do
      let(:instance) { FactoryBot.create(:models_instance, id: 123, availability_zone: 'az1') }
      let(:orphan_disk) do
        FactoryBot.create(:models_orphan_disk,
          disk_cid: 'disk456',
          size: 2048,
          availability_zone: 'az1',
          cloud_properties: { 'test_property' => '1' },
          cpi: 'some-cpi',
        )
      end

      it 'unorphans disks and snapshots' do
        snapshot = FactoryBot.create(:models_orphan_snapshot, orphan_disk: orphan_disk)

        returned_disk = disk_manager.unorphan_disk(orphan_disk, instance.id)
        persistent_disk = Models::PersistentDisk.first
        persistent_snapshot = Models::Snapshot.first

        expect(persistent_disk).to eq(returned_disk)

        expect(persistent_disk.disk_cid).to eq(orphan_disk.disk_cid)
        expect(persistent_disk.cpi).to eq('some-cpi')
        expect(persistent_snapshot.snapshot_cid).to eq(snapshot.snapshot_cid)
        expect(persistent_snapshot.persistent_disk).to eq(returned_disk)

        expect(Models::OrphanDisk.all.count).to eq(0)
        expect(Models::OrphanSnapshot.all.count).to eq(0)
      end
    end

    describe '#list_orphan_disk' do
      it 'returns an array of orphaned disks as hashes' do
        orphaned_at = Time.now.utc
        other_orphaned_at = Time.now.utc
        FactoryBot.create(:models_orphan_disk,
          disk_cid: 'random-disk-cid-1',
          instance_name: 'fake-name-1',
          size: 10,
          deployment_name: 'fake-deployment',
          created_at: orphaned_at,
        )
        FactoryBot.create(:models_orphan_disk,
          disk_cid: 'random-disk-cid-2',
          instance_name: 'fake-name-2',
          availability_zone: 'az2',
          deployment_name: 'fake-deployment',
          created_at: other_orphaned_at,
          cloud_properties: { 'cloud' => 'properties' },
        )

        expect(subject.list_orphan_disks).to eq(
          [
            {
              'disk_cid' => 'random-disk-cid-1',
              'size' => 10,
              'az' => nil,
              'deployment_name' => 'fake-deployment',
              'instance_name' => 'fake-name-1',
              'cloud_properties' => {},
              'orphaned_at' => orphaned_at.to_s,
            },
            {
              'disk_cid' => 'random-disk-cid-2',
              'size' => nil,
              'az' => 'az2',
              'deployment_name' => 'fake-deployment',
              'instance_name' => 'fake-name-2',
              'cloud_properties' => { 'cloud' => 'properties' },
              'orphaned_at' => other_orphaned_at.to_s,
            },
          ],
        )
      end
    end

    describe 'Deleting orphans' do
      let(:time) { Time.now.utc }
      let(:ten_seconds_ago) { time - 10 }
      let(:six_seconds_ago) { time - 6 }
      let(:five_seconds_ago) { time - 5 }
      let(:four_seconds_ago) { time - 4 }

      let(:event_log) { instance_double(EventLog::Log) }
      let(:stage) { instance_double(EventLog::Stage) }

      let(:orphan_disk_1) do
        FactoryBot.create(:models_orphan_disk, disk_cid: 'disk-cid-1', created_at: ten_seconds_ago, availability_zone: 'az1')
      end

      let(:orphan_disk_2) do
        FactoryBot.create(:models_orphan_disk, disk_cid: 'disk-cid-2', created_at: five_seconds_ago, availability_zone: 'az2')
      end

      let(:orphan_disk_cid_1) { orphan_disk_1.disk_cid }
      let(:orphan_disk_cid_2) { orphan_disk_2.disk_cid }

      let!(:orphan_disk_snapshot_1a) do
        FactoryBot.create(:models_orphan_snapshot, orphan_disk: orphan_disk_1, created_at: Time.now, snapshot_cid: 'snap-cid-a')
      end

      let!(:orphan_disk_snapshot_1b) do
        FactoryBot.create(:models_orphan_snapshot, orphan_disk: orphan_disk_1, created_at: Time.now, snapshot_cid: 'snap-cid-b')
      end

      let!(:orphan_disk_snapshot_2) do
        FactoryBot.create(:models_orphan_snapshot, orphan_disk: orphan_disk_2, created_at: Time.now, snapshot_cid: 'snap-cid-2')
      end

      before do
        allow(CloudFactory).to receive(:create).and_return(cloud_factory)
        allow(cloud).to receive(:delete_disk)
        allow(cloud).to receive(:delete_snapshot)
      end

      describe 'deleting an orphan disk by disk cid' do
        it 'deletes disks from the cloud and from the db' do
          expect(cloud).to receive(:delete_disk).with(orphan_disk_cid_1)
          expect(cloud_factory).to receive(:get).with(orphan_disk_1.cpi).at_least(:once).and_return(cloud)

          subject.delete_orphan_disk_by_disk_cid(orphan_disk_cid_1)

          expect(Models::OrphanDisk.where(disk_cid: orphan_disk_cid_1).all).to be_empty
          expect(Models::OrphanDisk.where(disk_cid: orphan_disk_cid_2).all).to_not be_empty
        end

        it 'deletes the orphan snapshots' do
          expect(Models::OrphanSnapshot.all).to_not be_empty
          expect(cloud).to receive(:delete_disk).with(orphan_disk_cid_1)
          expect(cloud).to receive(:delete_snapshot).with('snap-cid-a')
          expect(cloud).to receive(:delete_snapshot).with('snap-cid-b')
          expect(cloud).to_not receive(:delete_snapshot).with('snap-cid-2')
          expect(cloud_factory).to receive(:get).with(orphan_disk_1.cpi).at_least(:once).and_return(cloud)

          subject.delete_orphan_disk_by_disk_cid(orphan_disk_cid_1)

          expect(Models::OrphanSnapshot.all.map(&:snapshot_cid)).to eq(['snap-cid-2'])
        end

        context 'when user accidentally tries to delete an non-existent disk' do
          it 'raises DiskNotFound AND continues to delete the remaining disks' do
            expect(logger).to receive(:debug).with('Disk not found: non_existing_orphan_disk_cid')

            subject.delete_orphan_disk_by_disk_cid('non_existing_orphan_disk_cid')
          end
        end
      end

      describe 'deleting an orphan disk' do
        it 'deletes disks from the cloud and from the db' do
          expect(cloud).to receive(:delete_disk).with(orphan_disk_cid_1)
          expect(cloud_factory).to receive(:get).with(orphan_disk_1.cpi).at_least(:once).and_return(cloud)

          subject.delete_orphan_disk(orphan_disk_1)

          expect(Models::OrphanDisk.where(disk_cid: orphan_disk_cid_1).all).to be_empty
          expect(Models::OrphanDisk.where(disk_cid: orphan_disk_cid_2).all).to_not be_empty
        end

        it 'deletes the orphan snapshots' do
          expect(Models::OrphanSnapshot.all).to_not be_empty
          expect(cloud).to receive(:delete_disk).with(orphan_disk_cid_1)
          expect(cloud).to receive(:delete_snapshot).with('snap-cid-a')
          expect(cloud).to receive(:delete_snapshot).with('snap-cid-b')
          expect(cloud).to_not receive(:delete_snapshot).with('snap-cid-2')
          expect(cloud_factory).to receive(:get).with(orphan_disk_1.cpi).at_least(:once).and_return(cloud)

          subject.delete_orphan_disk(orphan_disk_1)

          expect(Models::OrphanSnapshot.all.map(&:snapshot_cid)).to eq(['snap-cid-2'])
        end

        it 'should store delete event' do
          expect(cloud).to receive(:delete_disk).with(orphan_disk_cid_1)
          expect(cloud).to receive(:delete_snapshot).with('snap-cid-a')
          expect(cloud).to receive(:delete_snapshot).with('snap-cid-b')
          expect(cloud).to_not receive(:delete_snapshot).with('snap-cid-2')
          expect(cloud_factory).to receive(:get).with(orphan_disk_1.cpi).at_least(:once).and_return(cloud)
          subject.delete_orphan_disk(orphan_disk_1)
          expect(Models::Event.all.count).to eq(2)

          event1 = Bosh::Director::Models::Event.first
          expect(event1.user).to eq(task.username)
          expect(event1.action).to eq('delete')
          expect(event1.object_type).to eq('disk')
          expect(event1.object_name).to eq('disk-cid-1')
          expect(event1.instance).to eq(orphan_disk_1.instance_name)
          expect(event1.deployment).to eq(orphan_disk_1.deployment_name)
          expect(event1.error).to be_nil
          expect(event1.task).to eq(task.id.to_s)

          event2 = Bosh::Director::Models::Event.all.last
          expect(event2.parent_id).to eq(event1.id)
          expect(event2.user).to eq(task.username)
          expect(event2.action).to eq('delete')
          expect(event2.object_type).to eq('disk')
          expect(event2.object_name).to eq('disk-cid-1')
          expect(event2.instance).to eq(orphan_disk_1.instance_name)
          expect(event2.deployment).to eq(orphan_disk_1.deployment_name)
          expect(event2.error).to be_nil
          expect(event2.task).to eq(task.id.to_s)
        end

        context 'when the snapshot is not found in the cloud' do
          it 'logs the error and continues to delete the remaining disks' do
            expect(cloud).to receive(:delete_snapshot).with('snap-cid-a').and_raise(Bosh::Clouds::DiskNotFound.new(false))
            expect(cloud_factory).to receive(:get).with(orphan_disk_1.cpi).at_least(:once).and_return(cloud)

            expect(logger).to receive(:debug).with('Disk not found in IaaS: snap-cid-a')
            subject.delete_orphan_disk(orphan_disk_1)
            expect(Models::OrphanSnapshot.where(orphan_disk_id: orphan_disk_1.id).all).to be_empty
          end
        end

        context 'when disk is not found in the cloud' do
          before do
            allow(cloud).to receive(:delete_disk).with(orphan_disk_cid_1).and_raise(Bosh::Clouds::DiskNotFound.new(false))
          end

          it 'logs the error to the debug log AND continues to delete the remaining disks' do
            expect(cloud_factory).to receive(:get).with(orphan_disk_1.cpi).at_least(:once).and_return(cloud)
            expect(logger).to receive(:debug).with("Disk not found in IaaS: #{orphan_disk_cid_1}")

            subject.delete_orphan_disk(orphan_disk_1)
            expect(Models::OrphanDisk.where(disk_cid: orphan_disk_cid_1).all).to be_empty
          end

          it 'should store event with error' do
            expect(cloud).to receive(:delete_disk).with(orphan_disk_cid_1)
            expect(cloud).to receive(:delete_snapshot).with('snap-cid-a')
            expect(cloud).to receive(:delete_snapshot).with('snap-cid-b')
            expect(cloud).to_not receive(:delete_snapshot).with('snap-cid-2')
            expect(cloud_factory).to receive(:get).with(orphan_disk_1.cpi).at_least(:once).and_return(cloud)
            subject.delete_orphan_disk(orphan_disk_1)
            expect(Models::Event.all.count).to eq(2)

            event1 = Bosh::Director::Models::Event.first
            expect(event1.user).to eq(task.username)
            expect(event1.action).to eq('delete')
            expect(event1.object_type).to eq('disk')
            expect(event1.object_name).to eq('disk-cid-1')
            expect(event1.instance).to eq(orphan_disk_1.instance_name)
            expect(event1.deployment).to eq(orphan_disk_1.deployment_name)
            expect(event1.error).to be_nil
            expect(event1.task).to eq(task.id.to_s)

            event2 = Bosh::Director::Models::Event.all.last
            expect(event2.parent_id).to eq(event1.id)
            expect(event2.user).to eq(task.username)
            expect(event2.action).to eq('delete')
            expect(event2.object_type).to eq('disk')
            expect(event2.object_name).to eq('disk-cid-1')
            expect(event2.instance).to eq(orphan_disk_1.instance_name)
            expect(event2.deployment).to eq(orphan_disk_1.deployment_name)
            expect(event2.error).to eq('Bosh::Clouds::DiskNotFound')
            expect(event2.task).to eq(task.id.to_s)
          end
        end

        context 'when CPI is unable to delete a disk' do
          it 'raises the error thrown by the CPI AND does NOT delete the disk from the database' do
            allow(cloud).to receive(:delete_disk).with(orphan_disk_cid_1).and_raise(Exception.new('Bad stuff happened!'))
            expect(cloud_factory).to receive(:get).with(orphan_disk_1.cpi).at_least(:once).and_return(cloud)

            expect do
              subject.delete_orphan_disk(orphan_disk_1)
            end.to raise_error Exception, 'Bad stuff happened!'

            expect(Models::OrphanDisk.where(disk_cid: orphan_disk_cid_1).all).not_to be_empty
          end
        end

        context 'when CPI is unable to delete a snapshot' do
          context 'and multiple snapshot are available' do
            before do
              allow(cloud).to receive(:delete_snapshot)
                .with(orphan_disk_snapshot_1a.snapshot_cid)
                .and_raise(Bosh::Clouds::CloudError.new('Bad stuff happened!'))

              allow(cloud).to receive(:delete_snapshot).with(orphan_disk_snapshot_1b.snapshot_cid)
              allow(cloud_factory).to receive(:get).with(orphan_disk_1.cpi).at_least(:once).and_return(cloud)
            end

            it 'deletes all other snapshots and raises' do
              expect do
                subject.delete_orphan_disk(orphan_disk_1)
              end.to raise_error Bosh::Clouds::CloudError, 'Failed to delete 1 snapshot(s) of disk disk-cid-1'

              expect(cloud).to have_received(:delete_snapshot).with(orphan_disk_snapshot_1a.snapshot_cid)
              expect(cloud).to have_received(:delete_snapshot).with(orphan_disk_snapshot_1b.snapshot_cid)
              expect(cloud).to_not have_received(:delete_disk).with(orphan_disk_cid_1)
            end

            it 'logs error' do
              allow(logger).to receive(:warn)
              allow(logger).to receive(:info)

              expect do
                subject.delete_orphan_disk(orphan_disk_1)
              end.to raise_error Bosh::Clouds::CloudError

              expect(logger).to have_received(:info)
                .with('Failed to deleted snapshot snap-cid-a disk of disk-cid-1. Failed with: Bad stuff happened!')
              expect(logger).to have_received(:warn)
            end

            context 'when snapshot disk is not found' do
              it 'logs the error and continues to delete the remaining disks' do
                allow(cloud).to receive(:delete_snapshot)
                  .with(orphan_disk_snapshot_1a.snapshot_cid)
                  .and_raise(Bosh::Clouds::DiskNotFound.new(false))
                allow(logger).to receive(:debug)

                subject.delete_orphan_disk(orphan_disk_1)

                expect(logger).to have_received(:debug).with('Disk not found in IaaS: snap-cid-a')
                expect(cloud).to have_received(:delete_snapshot).with(orphan_disk_snapshot_1b.snapshot_cid)
                expect(cloud).to have_received(:delete_disk).with(orphan_disk_cid_1)
              end
            end
          end

          context 'when a different exception than CloudError is thrown' do
            it 'catches it and raises CloudError' do
              allow(cloud).to receive(:delete_snapshot)
                .with(orphan_disk_snapshot_1a.snapshot_cid)
                .and_raise(Bosh::Clouds::ExternalCpi::UnknownError.new('Bad stuff happened!'))

              allow(cloud_factory).to receive(:get).with(orphan_disk_1.cpi).at_least(:once).and_return(cloud)

              expect do
                subject.delete_orphan_disk(orphan_disk_1)
              end.to raise_error Bosh::Clouds::CloudError, 'Failed to delete 1 snapshot(s) of disk disk-cid-1'
            end
          end
        end
      end
    end
  end
end
