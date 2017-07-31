require 'spec_helper'

module Bosh::Director
  describe BlobstoreDnsPublisher do
    include IpUtil

    let(:dns_encoder) do
      v = instance_double(LocalDnsEncoder)
      allow(v).to receive(:encode_az).with('az1').and_return(1)
      allow(v).to receive(:encode_az).with('az2').and_return(2)
      v
    end
    let(:blobstore) {  instance_double(Bosh::Blobstore::S3cliBlobstoreClient) }
    let(:domain_name) { 'fake-domain-name' }
    let(:agent_broadcaster) { instance_double(AgentBroadcaster) }
    subject(:dns) { BlobstoreDnsPublisher.new(lambda { blobstore }, domain_name, agent_broadcaster, dns_encoder, logger) }

    let(:deployment) { Models::Deployment.make(name: 'test-deployment') }

    let(:include_index_records) { false }
    let(:instance1) { Models::Instance.make(uuid: 'uuid1', index: 1) }

    before do
      allow(Config).to receive(:root_domain).and_return(domain_name)
      allow(Config).to receive(:local_dns_include_index?).and_return(false)
      allow(agent_broadcaster).to receive(:sync_dns)
      allow(agent_broadcaster).to receive(:filter_instances)
    end

    describe 'publish and broadcast' do
      let!(:original_local_dns_blob) { Models::LocalDnsBlob.make() }

      before do
        Bosh::Director::Models::LocalDnsRecord.make(
            instance_id: instance1.id,
            ip: '192.0.2.101',
            deployment: 'test-deployment',
            az: 'az1',
            instance_group: 'instance1',
            network: 'net-name1',
            agent_id: 'fake-agent-uuid1',
            domain: 'fake-domain-name'
        )

        Bosh::Director::Models::LocalDnsRecord.make(
            instance_id: instance1.id,
            ip: '192.0.3.101',
            deployment: 'test-deployment',
            az: 'az1',
            instance_group: 'instance1',
            network: 'net-name3',
            agent_id: 'fake-agent-uuid1',
            domain: 'fake-domain-name'
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
            network: 'net-name2',
            agent_id: 'fake-agent-uuid2',
            domain: 'fake-domain-name'
        )

        Bosh::Director::Models::LocalDnsRecord.make(instance_id: nil, ip: 'tombstone')
      end

      context 'when local_dns is not enabled' do
        before do
          allow(Config).to receive(:local_dns_enabled?).and_return(false)
        end

        it 'does nothing' do
          expect(agent_broadcaster).to_not receive(:sync_dns)
          dns.publish_and_broadcast
          expect(Models::LocalDnsBlob.last).to eq(original_local_dns_blob)
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
                  ['id', 'instance_group', 'az', 'az_id', 'network', 'deployment', 'ip', 'domain', 'agent_id'],
              'record_infos' => [
                  ['uuid1', 'instance1', 'az1', 1, 'net-name1', 'test-deployment', '192.0.2.101', 'fake-domain-name', 'fake-agent-uuid1'],
                  ['uuid1', 'instance1', 'az1', 1, 'net-name3', 'test-deployment', '192.0.3.101', 'fake-domain-name', 'fake-agent-uuid1'],
                  ['uuid2', 'instance2', 'az2', 2, 'net-name2', 'test-deployment', '192.0.2.102', 'fake-domain-name', 'fake-agent-uuid2']],
          })
          expect(blobstore).to receive(:create).with(expected_records).and_return('blob_id_1')
          dns.publish_and_broadcast
        end

        it 'creates a model representing the blob' do
          dns.publish_and_broadcast
          local_dns_blob = Bosh::Director::Models::LocalDnsBlob.last
          expect(local_dns_blob.blob.blobstore_id).to eq('blob_id_1')
          expect(local_dns_blob.version).to eq(4)
        end

        it 'broadcasts the blob to the agents' do
          expect(agent_broadcaster).to receive(:filter_instances).with(nil).and_return([])
          expect(agent_broadcaster).to receive(:sync_dns).with([], 'blob_id_1', '74f9711228b3b921c45c56057ee575689f0b45b7', 4)
          dns.publish_and_broadcast
        end

        context 'when the root_domain is empty' do
          before do
            instance3 = Models::Instance.make(
              uuid: 'uuid3',
              index: 3,
            )
            Bosh::Director::Models::LocalDnsRecord.make(
              instance_id: instance3.id,
              ip: '192.0.2.104',
              deployment: 'test-deployment',
              az: 'az2',
              instance_group: 'instance4',
              network: 'net-name2',
              agent_id: 'fake-agent-uuid4'
            )

          end

          it 'backfills the current root_domain' do
              expected_records = JSON.dump({
                'records' => [
                  ['192.0.2.101', 'uuid1.instance1.net-name1.test-deployment.fake-domain-name'],
                  ['192.0.3.101', 'uuid1.instance1.net-name3.test-deployment.fake-domain-name'],
                  ['192.0.2.102', 'uuid2.instance2.net-name2.test-deployment.fake-domain-name'],
                  ['192.0.2.104', 'uuid3.instance4.net-name2.test-deployment.fake-domain-name']],
                'version' => 5,
                'record_keys' =>
                  ['id', 'instance_group', 'az', 'az_id', 'network', 'deployment', 'ip', 'domain', 'agent_id'],
                'record_infos' => [
                  ['uuid1', 'instance1', 'az1', 1, 'net-name1', 'test-deployment', '192.0.2.101', 'fake-domain-name', 'fake-agent-uuid1'],
                  ['uuid1', 'instance1', 'az1', 1, 'net-name3', 'test-deployment', '192.0.3.101', 'fake-domain-name', 'fake-agent-uuid1'],
                  ['uuid2', 'instance2', 'az2', 2, 'net-name2', 'test-deployment', '192.0.2.102', 'fake-domain-name', 'fake-agent-uuid2'],
                  ['uuid3', 'instance4', 'az2', 2, 'net-name2', 'test-deployment', '192.0.2.104', 'fake-domain-name', 'fake-agent-uuid4']]
              })
              expect(blobstore).to receive(:create).with(expected_records).and_return('blob_id_1')
              dns.publish_and_broadcast
          end
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
                     ['id', 'instance_group', 'az', 'az_id', 'network', 'deployment', 'ip', 'domain', 'agent_id'],
                 'record_infos' => [
                     ['uuid1', 'instance1', 'az1', 1, 'net-name1', 'test-deployment', '192.0.2.101', 'fake-domain-name', 'fake-agent-uuid1'],
                     ['uuid1', 'instance1', 'az1', 1, 'net-name3', 'test-deployment', '192.0.3.101', 'fake-domain-name', 'fake-agent-uuid1'],
                     ['uuid2', 'instance2', 'az2', 2, 'net-name2', 'test-deployment', '192.0.2.102', 'fake-domain-name', 'fake-agent-uuid2']]
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
  end
end
