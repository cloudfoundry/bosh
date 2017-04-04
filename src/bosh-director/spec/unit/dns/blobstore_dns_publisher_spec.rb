require 'spec_helper'

module Bosh::Director
  describe BlobstoreDnsPublisher do
    include IpUtil

    let(:blobstore) { instance_double(Bosh::Blobstore::S3cliBlobstoreClient) }
    let(:domain_name) { 'fake-domain-name' }
    subject(:dns) { BlobstoreDnsPublisher.new(blobstore, domain_name) }

    let(:deployment) { Models::Deployment.make(name: 'test-deployment') }

    let(:dns_records) do
      dns_records = DnsRecords.new(2)
      dns_records.add_record('id0', 'group0', 'az0', 'net0', 'deployment0', 'fake-ip0', 'fake-name0')
      dns_records.add_record('id1', 'group1', 'az1', 'net1', 'deployment1', 'fake-ip1', 'fake-name1')
      dns_records
    end

    describe 'publish and broadcast' do
      let(:broadcaster) { instance_double(AgentBroadcaster) }

      before do
        instance1 = Models::Instance.make(uuid: 'uuid1')
        Bosh::Director::Models::LocalDnsRecord.make(
            instance_id: instance1.id,
            name: "uuid1.instance1.net-name1.test-deployment.#{domain_name}",
            ip: '192.0.2.101',
            deployment: 'test-deployment',
            az: 'az1',
            instance_group: 'instance1',
            network: 'net-name1'
        )

        Bosh::Director::Models::LocalDnsRecord.make(
            instance_id: instance1.id,
            name: "uuid1.instance1.net-name3.test-deployment.#{domain_name}",
            ip: '192.0.3.101',
            deployment: 'test-deployment',
            az: 'az1',
            instance_group: 'instance1',
            network: 'net-name3'
        )

        instance2 = Models::Instance.make(uuid: 'uuid2')
        Bosh::Director::Models::LocalDnsRecord.make(
            instance_id: instance2.id,
            name: "uuid2.instance2.net-name2.test-deployment.#{domain_name}",
            ip: '192.0.2.102',
            deployment: 'test-deployment',
            az: 'az2',
            instance_group: 'instance2',
            network: 'net-name2'
        )

        tombstone_dns_record = Bosh::Director::Models::LocalDnsRecord.make(
            instance_id: nil,
            name: 'tombstone',
            ip: '127.1.2.3')
      end

      context 'when local_dns is not enabled' do
        before do
          allow(Config).to receive(:local_dns_enabled?).and_return(false)
        end

        it 'does nothing' do
          expect(broadcaster).to_not receive(:sync_dns)
          dns.publish_and_broadcast
        end
      end

      context 'when local_dns is enabled' do
        let(:expected_dns_records) do
          dns_records = DnsRecords.new(4)
          dns_records.add_record('uuid1', 'instance1', 'az1', 'net-name1', 'test-deployment', '192.0.2.101', 'uuid1.instance1.net-name1.test-deployment.fake-domain-name')
          dns_records.add_record('uuid1', 'instance1', 'az1', 'net-name3', 'test-deployment', '192.0.3.101', 'uuid1.instance1.net-name3.test-deployment.fake-domain-name')
          dns_records.add_record('uuid2', 'instance2', 'az2', 'net-name2', 'test-deployment', '192.0.2.102', 'uuid2.instance2.net-name2.test-deployment.fake-domain-name')
          dns_records
        end

        before do
          allow(Config).to receive(:local_dns_enabled?).and_return(true)
          allow(blobstore).to receive(:create).and_return('blob_id_1')
        end

        it 'puts a blob containing the records into the blobstore' do
          expect(blobstore).to receive(:create).with(expected_dns_records.to_json).and_return('blob_id_1')
          dns.publish_and_broadcast
        end

        it 'creates a model represnting the blob' do
          dns.publish_and_broadcast
          local_dns_blob = Bosh::Director::Models::LocalDnsBlob.last
          expect(local_dns_blob.blobstore_id).to eq('blob_id_1')
          expect(local_dns_blob.sha1).to eq('a0dcf2caa8d2ffdfc1707f9c54f58b70b64ea7e3')
          expect(local_dns_blob.version).to eq(4)
        end

        it 'broadcasts the blob to the agents' do
          expect(AgentBroadcaster).to receive(:new).and_return(broadcaster)
          expect(broadcaster).to receive(:sync_dns).with('blob_id_1', 'a0dcf2caa8d2ffdfc1707f9c54f58b70b64ea7e3', 4)
          dns.publish_and_broadcast
        end

        context 'when putting to the blobstore fails' do
          it 'fails uploading records' do
            expect(blobstore).to receive(:create).and_raise(Bosh::Blobstore::BlobstoreError)

            expect {
              dns.publish_and_broadcast
            }.to raise_error(Bosh::Blobstore::BlobstoreError)
          end
        end

        it 'does not publish tombstone records' do
          expect(blobstore).to receive(:create) do |records_json|
            expect(records_json).to_not include('tombstone')
          end
          dns.publish_and_broadcast
        end
      end
    end

    describe '#cleanup_blobs' do
      context 'when there are no entries' do
        it 'does not do anything' do
          expect(Bosh::Director::Models::LocalDnsBlob.count).to eq 0
          expect(Bosh::Director::Models::EphemeralBlob.count).to eq 0
          expect { dns.cleanup_blobs }.to_not change { Bosh::Director::Models::LocalDnsBlob.count }
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
          expect { dns.cleanup_blobs }.to_not change { Bosh::Director::Models::LocalDnsBlob.count }
          expect(Bosh::Director::Models::LocalDnsBlob.all[0].id).to eq(1)
          expect(Bosh::Director::Models::EphemeralBlob.count).to eq(ephemeral_count)
        end
      end

      context 'when there are some entries' do
        before {
          3.times { Bosh::Director::Models::LocalDnsBlob.make }
        }

        it 'leaves the newest blob' do
          ephemeral_count = Bosh::Director::Models::EphemeralBlob.count
          expect { dns.cleanup_blobs }.to change { Bosh::Director::Models::LocalDnsBlob.count }.from(3).to(1)
          expect(Bosh::Director::Models::LocalDnsBlob.all[0].id).to eq(3)
          expect(Bosh::Director::Models::EphemeralBlob.count).to eq(ephemeral_count + 2)
        end
      end
    end
  end
end
