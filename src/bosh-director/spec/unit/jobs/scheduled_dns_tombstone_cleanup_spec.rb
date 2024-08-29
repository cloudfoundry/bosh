require 'spec_helper'

module Bosh::Director
  describe Jobs::ScheduledDnsTombstoneCleanup do
    subject { described_class.new }
    let(:task) { FactoryBot.create(:models_task, id: 42) }
    let(:task_writer) { Bosh::Director::TaskDBWriter.new(:event_output, task.id) }
    let(:event_log) { Bosh::Director::EventLog::Log.new(task_writer) }

    before do
      allow(Config).to receive(:event_log).and_return(event_log)
      Timecop.freeze(Time.now)
    end

    after do
      Timecop.return
    end

    describe '.has_work' do
      describe 'when there are more than one tombstone record' do
        before do
          Bosh::Director::Models::LocalDnsRecord.insert_tombstone
          Bosh::Director::Models::LocalDnsRecord.insert_tombstone
        end

        it 'should return true' do
          expect(described_class.has_work({})).to eq(true)
        end
      end

      describe 'when there is only one tombstone record' do
        before do
          Bosh::Director::Models::LocalDnsRecord.insert_tombstone
        end

        it 'should return false' do
          expect(described_class.has_work({})).to eq(false)
        end
      end
    end

    describe '.schedule_message' do
      it 'outputs a message' do
        expect(described_class.schedule_message).to eq('clean up local dns tombstone records')
      end
    end

    describe '.job_type' do
      it 'returns the job type' do
        expect(described_class.job_type).to eq(:scheduled_dns_tombstone_cleanup)
      end
    end

    describe '#perform' do
      context 'when multiple tombstone records exist' do
        let!(:oldest_tombstone) { Bosh::Director::Models::LocalDnsRecord.insert_tombstone }
        let!(:newest_tombstone) { Bosh::Director::Models::LocalDnsRecord.insert_tombstone }

        it 'deletes old tombstone records' do
          expect(subject.perform).to eq("Deleted 1 dns tombstone records")

          expect(Bosh::Director::Models::LocalDnsRecord.where(id: oldest_tombstone.id).first).to be_nil
          expect(Bosh::Director::Models::LocalDnsRecord.where(id: newest_tombstone.id).first).not_to be_nil
        end
      end

      context 'when only one tombstone record exists' do
        let!(:tombstone) { Bosh::Director::Models::LocalDnsRecord.insert_tombstone }

        it 'does not delete any' do
          expect(subject.perform).to eq("Deleted 0 dns tombstone records")

          expect(Bosh::Director::Models::LocalDnsRecord.where(id: tombstone.id).first).not_to be_nil
        end
      end
    end
  end
end
