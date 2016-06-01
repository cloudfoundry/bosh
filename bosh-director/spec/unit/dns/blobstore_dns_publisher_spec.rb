require 'spec_helper'
require 'blobstore_client/null_blobstore_client'

module Bosh::Director
  describe BlobstoreDnsPublisher do
    let(:blobstore) { Bosh::Blobstore::NullBlobstoreClient.new }
    subject(:dns) { BlobstoreDnsPublisher.new blobstore }
    let(:dns_records) { [['fake-ip0', 'fake-name0'], ['fake-ip1', 'fake-name1']]}

    describe '#publish' do
      context 'when blobstore publication succeeds' do
        context 'when some dns records are passed' do
          it 'uploads' do
            expect(blobstore).to receive(:create).with({:records => dns_records}.to_json).and_return('fake-blob-id')

            blobstore_id = dns.publish(dns_records)
            expect(blobstore_id).to_not be_nil

            expect(blobstore.exists?(blobstore_id)).to_not be_nil
          end
        end

        context 'when no dns records are passed' do
          it 'uploads empty records' do
            expect(blobstore).to receive(:create).with({:records => []}.to_json).and_return('fake-blob-id')

            blobstore_id = dns.publish([])
            expect(blobstore_id).to_not be_nil

            expect(blobstore.exists?(blobstore_id)).to_not be_nil
          end
        end
      end

      context 'when blobstore publication fails' do
        it 'fails uploading records' do
          expect(blobstore).to receive(:create).and_raise(Bosh::Blobstore::BlobstoreError)

          expect {
            dns.publish(dns_records)
          }.to raise_error(Bosh::Blobstore::BlobstoreError)
        end
      end
    end

    describe '#export_dns_records' do
      context 'when local store has DNS records' do
        before {
          Bosh::Director::Models::LocalDnsRecord.make(:ip => '192.0.2.1', :name => 'test-1.name.bosh')
          Bosh::Director::Models::LocalDnsRecord.make(:ip => '192.0.2.10', :name => 'test-10.name.bosh')
        }

        it 'exports the records' do
          expect(dns.export_dns_records).to eq([['192.0.2.1', 'test-1.name.bosh'], ['192.0.2.10', 'test-10.name.bosh']])
        end
      end

      context 'when local store has no DNS records' do
        it 'exports empty records' do
          expect(dns.export_dns_records).to eq([])
        end
      end
    end

    describe '#persist_dns_record' do
      context 'when dns record does not already exist' do
        it 'adds new [ip, name] to the DB' do
          dns.persist_dns_record('192.0.2.1', 'test-1.name.bosh')
          expect(Bosh::Director::Models::LocalDnsRecord.find(:ip => '192.0.2.1', :name => 'test-1.name.bosh')).to_not be_nil
        end
      end

      context 'when dns record already exists' do
        let(:timestamp) { Time.new('2001-01-01 01:01:01') }
        before {
          Bosh::Director::Models::LocalDnsRecord.make(:ip => '192.0.2.10', :name => 'test-10.name.bosh', :timestamp => timestamp)
        }

        it 'updates the record' do
          dns.persist_dns_record('192.0.2.11', 'test-10.name.bosh')
          expect(Bosh::Director::Models::LocalDnsRecord.find(:ip => '192.0.2.10', :name => 'test-10.name.bosh')).to be_nil
          expect(Bosh::Director::Models::LocalDnsRecord.find(:ip => '192.0.2.11', :name => 'test-10.name.bosh')).to_not be_nil
        end

        it 'ignores updates if record did not change' do
          dns.persist_dns_record('192.0.2.10', 'test-10.name.bosh')
          record = Bosh::Director::Models::LocalDnsRecord.find(:ip => '192.0.2.10', :name => 'test-10.name.bosh')
          expect(record).to_not be_nil
          expect(record.timestamp).to_not eq(timestamp)
        end
      end
    end

    describe '#delete_dns_record' do
      context 'when dns record does not already exist' do
        it 'silently ignores deletes on non-present entries' do
          expect{ dns.delete_dns_record('test-10.name.bosh') }.to_not change{ Bosh::Director::Models::LocalDnsRecord.count }
        end
      end

      context 'when dns record already exists' do
        before {
          Bosh::Director::Models::LocalDnsRecord.make(:ip => '192.0.2.10', :name => 'test-10.name.bosh')
        }

        it 'deletes the entry' do
          expect { dns.delete_dns_record('test-10.name.bosh') }.to change{ Bosh::Director::Models::LocalDnsRecord.count }.from(1).to(0)
        end
      end

      context 'backwards compatibility with old deployments missing dns records' do
        context 'when there is a positive match' do
          before {
            Bosh::Director::Models::LocalDnsRecord.make(:ip => '192.0.2.10', :name => 'test-10.name.bosh')
          }

          it 'deletes entry'do
            expect { dns.delete_dns_record('test-10.%.bosh') }.to change{ Bosh::Director::Models::LocalDnsRecord.count }.from(1).to(0)
          end
        end

        context 'when there is no match' do
          it 'silently ignores deletes on non-present entries' do
            expect{ dns.delete_dns_record('test-10.%.bosh') }.to_not change{ Bosh::Director::Models::LocalDnsRecord.count }
          end
        end
      end
    end
  end
end
