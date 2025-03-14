require 'spec_helper'

module Bosh::Director
  describe Jobs::ScheduledDnsBlobsCleanup do
    subject { described_class.new(*params) }
    let(:params) do
      [{
        'max_blob_age' => max_blob_age,
        'num_dns_blobs_to_keep' => num_dns_blobs_to_keep
      }]
    end
    let(:num_dns_blobs_to_keep) { 0 }
    let(:max_blob_age) { 10 }
    let(:task) { FactoryBot.create(:models_task, id: 42) }
    let!(:old_dns_blob) { FactoryBot.create(:models_local_dns_blob, created_at: Time.now - oldest_dns_blob_age) }
    let(:task_writer) {Bosh::Director::TaskDBWriter.new(:event_output, task.id)}
    let(:event_log) {Bosh::Director::EventLog::Log.new(task_writer)}
    let(:oldest_dns_blob_age) { 5 }
    let(:blobstore) { instance_double(Bosh::Director::Blobstore::Client) }

    before do
      allow(Config).to receive(:event_log).and_return(event_log)
      Timecop.freeze(Time.now)
    end

    describe '.has_work' do
      context 'when there are more than the given num_dns_blobs_to_keep' do
        describe 'when there an old blob' do
          let(:oldest_dns_blob_age) { max_blob_age + 1 }

          it 'should return true' do
            expect(described_class.has_work(params)).to eq(true)
          end
        end

        context 'when there is only a new blob' do
          let(:oldest_dns_blob_age) { max_blob_age - 1 }

          it 'should return false' do
            expect(described_class.has_work(params)).to eq(false)
          end
        end
      end

      context 'when there are not more than the given num_dns_blobs_to_keep' do
        let(:num_dns_blobs_to_keep) { 1 }

        it 'returns false' do
          expect(described_class.has_work(params)).to eq(false)
        end
      end
    end

    describe '.schedule_message' do
      it 'outputs a message' do
        expect(described_class.schedule_message).to eq('clean up local dns blobs')
      end
    end

    describe '.job_type' do
      it 'returns the job type' do
        expect(described_class.job_type).to eq(:scheduled_dns_blobs_cleanup)
      end
    end

    describe '#perform' do
      let(:oldest_dns_blob_age) { max_blob_age + 1 }

      before do
        allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
        allow(blobstore).to receive(:delete)
      end

      it 'deletes old blobs' do
        expect(subject.perform).to eq("Deleted 1 dns blob(s) created before #{Time.now - max_blob_age}")

        expect(Models::LocalDnsBlob.all).to be_empty
        expect(Models::Blob.all).to be_empty
      end

      it 'deletes blob from blobstore' do
        expect(blobstore).to receive(:delete).with(old_dns_blob.blob.blobstore_id)

        subject.perform
      end

      context 'when deleting all old blobs would reduce number of blobs to less than num_dns_blobs_to_keep' do
        let(:oldest_dns_blob_age) { max_blob_age + 2 }
        let!(:recent_blob) { FactoryBot.create(:models_local_dns_blob, created_at: Time.now - (oldest_dns_blob_age - 1)) }
        let(:num_dns_blobs_to_keep) { 1 }

        it 'only deletes oldest blobs until num_dns_blobs_to_keep remain' do
          subject.perform
          expect(Models::LocalDnsBlob.all).to contain_exactly(recent_blob)
          expect(Models::Blob.all).to contain_exactly(recent_blob.blob)
        end
      end

      context 'when only new blobs exist' do
        let(:oldest_dns_blob_age) { max_blob_age - 1 }
        let(:num_dns_blobs_to_keep) { 0 }

        it 'does not delete any' do
          expect(subject.perform).to eq("Deleted 0 dns blob(s) created before #{Time.now - max_blob_age}")

          expect(Models::LocalDnsBlob.all).to contain_exactly(old_dns_blob)
          expect(Models::Blob.all).to contain_exactly(old_dns_blob.blob)
        end
      end
    end
  end
end
