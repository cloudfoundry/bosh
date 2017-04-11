require 'spec_helper'

module Bosh::Director
  describe BlobstoreDnsPublisher do
    include IpUtil

    let(:blobstore) {  instance_double(Bosh::Blobstore::S3cliBlobstoreClient) }
    let(:domain_name) { 'fake-domain-name' }
    let(:agent_broadcaster) { instance_double(AgentBroadcaster) }
    subject(:dns) { BlobstoreDnsPublisher.new(lambda { blobstore }, domain_name, agent_broadcaster, logger) }

    let(:deployment) { Models::Deployment.make(name: 'test-deployment') }

    let(:include_index_records) { false }
    let(:dns_records) do
      dns_records = DnsRecords.new(2, include_index_records)
      dns_records.add_record('id0', 'group0', 'az0', 'net0', 'deployment0', 'fake-ip0', 'fake-name0')
      dns_records.add_record('id1', 'group1', 'az1', 'net1', 'deployment1', 'fake-ip1', 'fake-name1')
      dns_records
    end

    before do
      allow(Config).to receive(:canonized_dns_domain_name).and_return(domain_name)
      allow(Config).to receive(:local_dns_include_index?).and_return(false)
      allow(agent_broadcaster).to receive(:sync_dns)
    end

    describe 'publish and broadcast' do

      before do
        instance1 = Models::Instance.make(
            uuid: 'uuid1',
            index: 1,
        )
        Bosh::Director::Models::LocalDnsRecord.make(
            instance_id: instance1.id,
            ip: '192.0.2.101',
            deployment: 'test-deployment',
            az: 'az1',
            instance_group: 'instance1',
            network: 'net-name1'
        )

        Bosh::Director::Models::LocalDnsRecord.make(
            instance_id: instance1.id,
            ip: '192.0.3.101',
            deployment: 'test-deployment',
            az: 'az1',
            instance_group: 'instance1',
            network: 'net-name3'
        )

        instance2 = Models::Instance.make(
            uuid: 'uuid2',
            index: 2,
        )
        Bosh::Director::Models::LocalDnsRecord.make(
            instance_id: instance2.id,
            ip: '192.0.2.102',
            deployment: 'test-deployment',
            az: 'az2',
            instance_group: 'instance2',
            network: 'net-name2'
        )

        Bosh::Director::Models::LocalDnsRecord.make(instance_id: nil, ip: 'tombstone')
      end

      context 'when local_dns is not enabled' do
        before do
          allow(Config).to receive(:local_dns_enabled?).and_return(false)
        end

        it 'does nothing' do
          expect(Bosh::Director::Models::LocalDnsBlob.last).to be_nil
          expect(agent_broadcaster).to_not receive(:sync_dns)
          dns.publish_and_broadcast
        end
      end

      context 'when local_dns is enabled' do
        before do
          allow(Config).to receive(:local_dns_enabled?).and_return(true)
          allow(blobstore).to receive(:create).and_return('blob_id_1')
        end

        it 'puts a blob containing the records into the blobstore' do
          expected_records = JSON.dump({
              'records' => [
                  ['192.0.2.101', 'uuid1.instance1.net-name1.test-deployment.fake-domain-name'],
                  ['192.0.3.101', 'uuid1.instance1.net-name3.test-deployment.fake-domain-name'],
                  ['192.0.2.102', 'uuid2.instance2.net-name2.test-deployment.fake-domain-name']],
              'version' => 4,
              'record_keys' =>
                  ['id', 'instance_group', 'az', 'network', 'deployment', 'ip'],
              'record_infos' => [
                  ['uuid1', 'instance1', 'az1', 'net-name1', 'test-deployment', '192.0.2.101'],
                  ['uuid1', 'instance1', 'az1', 'net-name3', 'test-deployment', '192.0.3.101'],
                  ['uuid2', 'instance2', 'az2', 'net-name2', 'test-deployment', '192.0.2.102']]
          })
          expect(blobstore).to receive(:create).with(expected_records).and_return('blob_id_1')
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
          expect(agent_broadcaster).to receive(:sync_dns).with('blob_id_1', 'a0dcf2caa8d2ffdfc1707f9c54f58b70b64ea7e3', 4)
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

        context 'when index based records are enabled' do
          before do
            allow(Config).to receive(:local_dns_include_index?).and_return(true)
          end

          it 'should include index records too' do
            expected_records = JSON.dump({
                 'records' => [
                     ['192.0.2.101', 'uuid1.instance1.net-name1.test-deployment.fake-domain-name'],
                     ['192.0.2.101', '1.instance1.net-name1.test-deployment.fake-domain-name'],
                     ['192.0.3.101', 'uuid1.instance1.net-name3.test-deployment.fake-domain-name'],
                     ['192.0.3.101', '1.instance1.net-name3.test-deployment.fake-domain-name'],
                     ['192.0.2.102', 'uuid2.instance2.net-name2.test-deployment.fake-domain-name'],
                     ['192.0.2.102', '2.instance2.net-name2.test-deployment.fake-domain-name']],
                 'version' => 4,
                 'record_keys' =>
                     ['id', 'instance_group', 'az', 'network', 'deployment', 'ip'],
                 'record_infos' => [
                     ['uuid1', 'instance1', 'az1', 'net-name1', 'test-deployment', '192.0.2.101'],
                     ['uuid1', 'instance1', 'az1', 'net-name3', 'test-deployment', '192.0.3.101'],
                     ['uuid2', 'instance2', 'az2', 'net-name2', 'test-deployment', '192.0.2.102']]
             })

            expect(blobstore).to receive(:create).with(expected_records).and_return('blob_id_1')
            dns.publish_and_broadcast
          end
        end

        context 'when the dns blobs are up to date' do
          it 'does not generate a new blob' do
            dns.publish_and_broadcast

            expect(blobstore).to_not receive(:create)
            dns.publish_and_broadcast
          end

          it 'does not broadcast' do
            dns.publish_and_broadcast

            expect(agent_broadcaster).to receive(:sync_dns)
            dns.publish_and_broadcast
          end
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
        before { Bosh::Director::Models::LocalDnsBlob.make }

        it 'leaves the only and newest blob' do
          ephemeral_count = Bosh::Director::Models::EphemeralBlob.count
          expect { dns.cleanup_blobs }.to_not change { Bosh::Director::Models::LocalDnsBlob.count }
          expect(Bosh::Director::Models::LocalDnsBlob.all[0].id).to eq(1)
          expect(Bosh::Director::Models::EphemeralBlob.count).to eq(ephemeral_count)
        end
      end

      context 'when there are some entries' do
        before { 3.times { Bosh::Director::Models::LocalDnsBlob.make } }

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
