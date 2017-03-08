require 'spec_helper'

module Bosh::Director
  describe BlobstoreDnsPublisher do
    let(:blobstore) { instance_double(Bosh::Blobstore::S3cliBlobstoreClient) }
    let(:domain_name) { 'fake-domain-name' }
    subject(:dns) { BlobstoreDnsPublisher.new(blobstore, domain_name) }
    let(:dns_records) { DnsRecords.new([['fake-ip0', 'fake-name0'], ['fake-ip1', 'fake-name1']], 2)}

    describe '#publish' do
      context 'when blobstore publication succeeds' do
        context 'when some dns records are passed' do
          before {
            expect(blobstore).to receive(:create).with(dns_records.to_json).and_return('fake-blob-id')
          }

          it 'uploads' do
            blobstore_id = dns.publish(dns_records)
            expect(blobstore_id).to_not be_nil

            expect(blobstore).to receive(:exists?).and_return(false)
            expect(blobstore.exists?(blobstore_id)).to_not be_nil
          end

          it 'adds new entry to LocalDnsBlob table' do
            blobstore_id = dns.publish(dns_records)
            local_dns_blob = Bosh::Director::Models::LocalDnsBlob.find(:blobstore_id => blobstore_id)
            expect(local_dns_blob.sha1).to eq(::Digest::SHA1.hexdigest(dns_records.to_json))
            expect(local_dns_blob.version).to eq(2)
          end
        end

        context 'when no dns records are passed' do
          it 'uploads empty records' do
            expect(blobstore).to receive(:create).with({:records => [], :version => 0}.to_json).and_return('fake-blob-id')

            blobstore_id = dns.publish(DnsRecords.new)
            expect(blobstore_id).to_not be_nil

            expect(blobstore).to receive(:exists?).and_return(false)
            expect(blobstore.exists?(blobstore_id)).to_not be_nil
          end
        end
      end

      describe '#broadcast' do
        context 'when LocalDnsBlob has records' do
            before {
              Models::LocalDnsBlob.create(blobstore_id: 'fake-blob-id0',
                                          sha1: 'fakesha0',
                                          version: 1,
                                          :created_at => Time.new)
              Models::LocalDnsBlob.create(blobstore_id: 'fake-blob-id1',
                                          sha1: 'fakesha1',
                                          version: 2,
                                          :created_at => Time.new)
            }

            let(:broadcaster) { double(AgentBroadcaster) }

            it 'retrieves the last blob' do
              expect(AgentBroadcaster).to receive(:new).and_return(broadcaster)
              expect(broadcaster).to receive(:sync_dns).with('fake-blob-id1', 'fakesha1', 2)
              dns.broadcast
            end
          end

          context 'when LocalDnsBlob is empty' do
            it 'does nothing' do
              expect(AgentBroadcaster).to_not receive(:broadcast)
              dns.broadcast
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
      context 'when local store has no DNS records' do
        it 'exports empty records' do
          expect(dns.export_dns_records.records).to eq([])
          expect(dns.export_dns_records.version).to eq(0)
        end
      end

      context 'when there exist some DNS records' do
        before {
          instance2 = Bosh::Director::Models::Instance.make(:spec => { 'deployment' => 'test-deployment',
                                                                       'index' => 0,
                                                                       'job' => { 'name' => 'instance2' },
                                                                       'id' => 'uuid2',
                                                                       'networks' => { 'net-name2' => { 'ip' => '192.0.2.102' } }})


          Bosh::Director::Models::LocalDnsRecord.make(:instance_id => instance2.id,
                                                      :name => "uuid2.instance2.net-name2.test-deployment.#{domain_name}",
                                                      :ip => '192.0.2.102')
        }

        context 'when local store has many DNS records' do
          before {
            instance1 = Bosh::Director::Models::Instance.make(:spec => { 'deployment' => 'test-deployment',
                                                                         'index' => 0,
                                                                         'job' => { 'name' => 'instance1' },
                                                                         'id' => 'uuid1',
                                                                         'networks' => { 'net-name1' => { 'ip' => '192.0.2.101' },
                                                                                         'net-name3' => { 'ip' => '192.0.3.101' } }})

            Bosh::Director::Models::LocalDnsRecord.make(:instance_id => instance1.id,
                                                        :name => "uuid1.instance1.net-name1.test-deployment.#{domain_name}",
                                                        :ip => '192.0.2.101')

            Bosh::Director::Models::LocalDnsRecord.make(:instance_id => instance1.id,
                                                        :name => "uuid1.instance1.net-name3.test-deployment.#{domain_name}",
                                                        :ip => '192.0.3.101')
          }

          it 'exports the records' do
            expect(dns.export_dns_records.records).to eq([['192.0.2.102', "uuid2.instance2.net-name2.test-deployment.#{domain_name}"],
                                                          ['192.0.2.101', "uuid1.instance1.net-name1.test-deployment.#{domain_name}"],
                                                          ['192.0.3.101', "uuid1.instance1.net-name3.test-deployment.#{domain_name}"]])
            expect(dns.export_dns_records.version).to eq(3)
          end
        end

        context 'when local store has one DNS records' do
          it 'exports the record' do
            expect(dns.export_dns_records.records).to eq([['192.0.2.102', "uuid2.instance2.net-name2.test-deployment.#{domain_name}"]])
            expect(dns.export_dns_records.version).to eq(1)
          end
        end

        context 'when there are tombstone records' do
          before do
            Bosh::Director::Models::LocalDnsRecord.make(
              instance_id: nil,
              name: 'foo',
              ip: '192.0.2.102')
          end

          it 'does not include the tombstone records' do
            expect(dns.export_dns_records.records).to eq([['192.0.2.102', "uuid2.instance2.net-name2.test-deployment.#{domain_name}"]])
            expect(dns.export_dns_records.version).to eq(2)
          end
        end
      end
    end

    describe '#cleanup_blobs' do
      context 'when there are no entries' do
        it 'does not do anything' do
          expect(Bosh::Director::Models::LocalDnsBlob.count).to eq 0
          expect(Bosh::Director::Models::EphemeralBlob.count).to eq 0
          expect{ dns.cleanup_blobs }.to_not change{ Bosh::Director::Models::LocalDnsBlob.count }
          expect(Bosh::Director::Models::LocalDnsBlob.count).to eq 0
          expect(Bosh::Director::Models::EphemeralBlob.count).to eq 0
        end
      end

      context 'when there is one entry' do
        before {
          Bosh::Director::Models::LocalDnsBlob.make
        }

        it 'leaves the only and newest blob' do
          ephemeral_count = Bosh::Director::Models::EphemeralBlob.count
          expect{ dns.cleanup_blobs }.to_not change{ Bosh::Director::Models::LocalDnsBlob.count }
          expect(Bosh::Director::Models::LocalDnsBlob.all[0].id).to eq(1)
          expect(Bosh::Director::Models::EphemeralBlob.count).to eq(ephemeral_count)
        end
      end

      context 'when there are some entries' do
        before {
          3.times{Bosh::Director::Models::LocalDnsBlob.make}
        }

        it 'leaves the newest blob' do
          ephemeral_count = Bosh::Director::Models::EphemeralBlob.count
          expect{ dns.cleanup_blobs }.to change{ Bosh::Director::Models::LocalDnsBlob.count }.from(3).to(1)
          expect(Bosh::Director::Models::LocalDnsBlob.all[0].id).to eq(3)
          expect(Bosh::Director::Models::EphemeralBlob.count).to eq(ephemeral_count + 2)
        end
      end
    end
  end
end
