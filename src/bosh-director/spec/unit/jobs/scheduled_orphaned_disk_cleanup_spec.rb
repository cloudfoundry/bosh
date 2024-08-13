require 'spec_helper'

module Bosh::Director
  describe Jobs::ScheduledOrphanedDiskCleanup do
    subject { described_class.new(*params) } # Resque splats the params Array before giving it to the ctor
    let(:params) do
      [{
        'max_orphaned_age_in_days' => max_orphaned_age_in_days,
      }]
    end
    let(:max_orphaned_age_in_days) { 1 }
    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
    let(:cloud_factory) { instance_double(Bosh::Director::CloudFactory) }
    let(:time) { Time.now }
    let(:one_day_seconds) { 24 * 60 * 60 }
    let(:one_day_one_second_ago) { time - one_day_seconds - 1 }
    let(:less_than_one_day_ago) { time - one_day_seconds + 1 }
    let!(:orphan_disk_1) { Models::OrphanDisk.make(disk_cid: 'disk-cid-1', created_at: one_day_one_second_ago) }
    let!(:orphan_disk_2) { Models::OrphanDisk.make(disk_cid: 'disk-cid-2', created_at: less_than_one_day_ago) }
    let(:task) { FactoryBot.create(:models_task, id: 42) }
    let(:task_writer) { Bosh::Director::TaskDBWriter.new(:event_output, task.id) }
    let(:event_log) { Bosh::Director::EventLog::Log.new(task_writer) }
    let(:event_manager) { Api::EventManager.new(true) }
    let(:task) { FactoryBot.create(:models_task, id: 42, username: 'user') }

    let(:scheduled_orphaned_disk_cleanup_job) do
      instance_double(
        Bosh::Director::Jobs::ScheduledOrphanedDiskCleanup,
        username: 'user',
        task_id: task.id,
        event_manager: event_manager,
      )
    end

    before do
      allow(Bosh::Director::CloudFactory).to receive(:create).and_return(cloud_factory)
      allow(cloud_factory).to receive(:get).with('').and_return(cloud)
      allow(Config).to receive(:current_job).and_return(scheduled_orphaned_disk_cleanup_job)
    end

    describe '#has_work' do
      describe 'when there is work to do' do
        it 'should return true' do
          expect(described_class.has_work(params)).to eq(true)
        end
      end

      describe 'when there is no work to do' do
        let(:max_orphaned_age_in_days) { 2 }

        it 'should return false' do
          expect(described_class.has_work(params)).to eq(false)
        end
      end
    end

    describe 'performing the job' do
      before do
        allow(Time).to receive(:now).and_return(time)
        allow(cloud).to receive(:delete_disk).with('disk-cid-1')
      end

      it 'deletes orphans older than days specified' do
        subject.perform
        expect(Models::OrphanDisk.all.map(&:disk_cid)).to eq(['disk-cid-2'])
      end

      it 'should show the count deleted' do
        expect(subject.perform)
          .to eq("Deleted 1 orphaned disk(s) older than #{time - one_day_seconds}. Failed to delete 0 disk(s).")
      end

      context 'when CPI is unable to delete a disk' do
        let(:orphan_disk_manager) { instance_double(OrphanDiskManager) }

        before do
          allow(OrphanDiskManager).to receive(:new).and_return(orphan_disk_manager)
        end

        context 'and multiple orphan disks' do
          let(:orphan_disk_2) { Models::OrphanDisk.make(disk_cid: 'disk-cid-2', created_at: one_day_one_second_ago) }

          it 'cleans all disks and raises the error thrown by the CPI' do
            allow(orphan_disk_manager)
              .to receive(:delete_orphan_disk)
              .with(orphan_disk_1)
              .and_raise(Bosh::Clouds::CloudError.new('Bad stuff happened!'))

            allow(orphan_disk_manager)
              .to receive(:delete_orphan_disk)
              .with(orphan_disk_2)

            expect { subject.perform }.to raise_error(
              Bosh::Clouds::CloudError,
              "Deleted 1 orphaned disk(s) older than #{time - one_day_seconds}. Failed to delete 1 disk(s).",
            )

            expect(orphan_disk_manager).to have_received(:delete_orphan_disk).with(orphan_disk_1)
            expect(orphan_disk_manager).to have_received(:delete_orphan_disk).with(orphan_disk_2)
          end
        end

        it 'logs the failer and raises the error thrown by the CPI' do
          logger = double('logger', warn: nil, info: nil)
          allow(orphan_disk_manager)
            .to receive(:delete_orphan_disk).and_raise(Bosh::Clouds::CloudError.new('Bad stuff happened!'))
          allow(subject).to receive(:logger).and_return(logger)

          expect { subject.perform }
            .to raise_error(
              Bosh::Clouds::CloudError,
              "Deleted 0 orphaned disk(s) older than #{time - one_day_seconds}. Failed to delete 1 disk(s).",
            )

          expect(logger).to have_received(:warn)
          expect(logger).to have_received(:info)
            .with("Failed to delete orphan disk with cid #{orphan_disk_1.disk_cid}. Failed with Bad stuff happened!")
        end

        context 'when a different exception than CloudError is thrown' do
          it 'catches it and raises CloudError' do
            allow(orphan_disk_manager).to receive(:delete_orphan_disk)
              .and_raise(Bosh::Clouds::ExternalCpi::UnknownError.new('Bad stuff happened!'))

            expect { subject.perform }
              .to raise_error(
                Bosh::Clouds::CloudError,
                "Deleted 0 orphaned disk(s) older than #{time - one_day_seconds}. Failed to delete 1 disk(s).",
              )
          end
        end
      end
    end
  end
end
