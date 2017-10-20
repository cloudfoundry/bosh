require 'spec_helper'

module Bosh::Director
  describe Jobs::OrphanDiskJob do
    subject(:job) { described_class.new(disk_cid) }
    before do
      allow(Bosh::Director::Config).to receive(:record_events).and_return(true)
      allow(job).to receive(:task_id).and_return(task.id)
      allow(Bosh::Director::Config).to receive(:current_job).and_return(orphan_disk_job)
      allow(Bosh::Director::Config).to receive(:event_log).and_return(event_log)
      allow(event_log).to receive(:begin_stage).and_return(stage)
      allow(stage).to receive(:advance_and_track).and_yield
    end

    let(:disk_cid) { 'disk_cid' }
    let(:task) { Bosh::Director::Models::Task.make(:id => 42, :username => 'user') }
    let(:event_manager) { Bosh::Director::Api::EventManager.new(true) }
    let(:orphan_disk_job) { instance_double(Bosh::Director::Jobs::OrphanDiskJob, username: 'user', task_id: task.id, event_manager: event_manager) }
    let(:cloud) { Config.cloud }
    let(:task_writer) {Bosh::Director::TaskDBWriter.new(:event_output, task.id)}
    let(:event_log){ Bosh::Director::EventLog::Log.new(task_writer) }
    let(:stage) { instance_double(Bosh::Director::EventLog::Stage) }

    describe 'perform' do
      describe 'DJ job class expectations' do
        let(:job_type) { :orphan_disk }
        let(:queue) { :normal }
        it_behaves_like 'a DJ job'
      end

      it 'should orphan disk' do
        persistent_disk = Models::PersistentDisk.make(disk_cid: 'disk_cid', size: 2048, cloud_properties: {'cloud' => 'properties'}, active: true)
        snapshot = Models::Snapshot.make(persistent_disk: persistent_disk)
        expect(cloud).to_not receive(:delete_disk).with(disk_cid)
        expect(cloud).to_not receive(:delete_snapshot).with(snapshot.snapshot_cid)
        expect(event_log).to receive(:begin_stage).with('Orphan disk', 1).and_return(stage)
        expect(stage).to receive(:advance_and_track).with('disk_cid')
        expect(job.perform).to eq 'disk disk_cid orphaned'

        orphan_disk = Models::OrphanDisk.first
        orphan_snapshot = Models::OrphanSnapshot.first

        expect(orphan_disk.disk_cid).to eq(persistent_disk.disk_cid)
        expect(orphan_snapshot.snapshot_cid).to eq(snapshot.snapshot_cid)
        expect(orphan_snapshot.orphan_disk).to eq(orphan_disk)

        expect(Models::PersistentDisk.all.count).to eq(0)
        expect(Models::Snapshot.all.count).to eq(0)
      end

      it 'should not raise error' do
        Models::PersistentDisk.make(disk_cid: 'disk_cid_2', size: 2048, cloud_properties: {'cloud' => 'properties'}, active: true)
        expect(logger).to receive(:info).with("disk disk_cid does not exist")
        expect(stage).to receive(:advance_and_track).with('disk_cid')
        expect(event_log).to receive(:warn).with('Disk disk_cid does not exist. Orphaning is skipped')
        expect(job.perform).to eq 'disk disk_cid orphaned'
      end

      it 'should raise error' do
        persistent_disk = Models::PersistentDisk.make(disk_cid: 'disk_cid', cloud_properties: {'cloud' => 'properties'}, size: 2048, active: true)

        conflicting_orphan_disk = Models::OrphanDisk.make
        conflicting_orphan_snapshot = Models::OrphanSnapshot.make(
          orphan_disk: conflicting_orphan_disk,
          snapshot_cid: 'existing_cid',
          snapshot_created_at: Time.now
        )

        Models::Snapshot.make(
          snapshot_cid: 'existing_cid',
          persistent_disk: persistent_disk
        )

        expect { job.perform }.to raise_error(Sequel::ValidationFailed)

        conflicting_orphan_snapshot.destroy
        conflicting_orphan_disk.destroy

        expect(Models::PersistentDisk.all.count).to eq(1)
        expect(Models::Snapshot.all.count).to eq(1)
        expect(Models::OrphanDisk.all.count).to eq(0)
        expect(Models::OrphanSnapshot.all.count).to eq(0)
      end
    end
  end
end
