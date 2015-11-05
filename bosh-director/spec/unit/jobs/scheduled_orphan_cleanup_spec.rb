require 'spec_helper'

module Bosh::Director
  describe Jobs::ScheduledOrphanCleanup do
    subject { described_class.new({
        'max_orphaned_age_in_days' => max_orphaned_age_in_days,
        :cloud => cloud
      }) }

    let(:max_orphaned_age_in_days) { 1 }
    let(:cloud) { instance_double(Bosh::Cloud) }

    describe 'performing the job' do
      let(:time) { Time.now }
      let(:one_day_seconds) { 24 * 60 * 60 }
      let(:one_day_one_second_ago) { time - one_day_seconds - 1 }
      let(:less_than_one_day_ago) { time - one_day_seconds + 1 }

      let!(:orphan_disk_1) { Models::OrphanDisk.make(disk_cid: 'disk-cid-1', orphaned_at: one_day_one_second_ago) }
      let!(:orphan_disk_2) { Models::OrphanDisk.make(disk_cid: 'disk-cid-2', orphaned_at: less_than_one_day_ago) }
      before { allow(cloud).to receive(:delete_disk).with('disk-cid-1') }

      it 'deletes orphans older than days specified' do
        subject.perform
        expect(Models::OrphanDisk.all.map(&:disk_cid)).to eq(['disk-cid-2'])
      end
    end
  end
end
