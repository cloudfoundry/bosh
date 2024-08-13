require 'spec_helper'

module Bosh::Director
  describe BlobstoreDnsPublisher do
    include IpUtil

    subject(:dns) { BlobstoreDnsPublisher.new(-> { blobstore }, domain_name, agent_broadcaster, logger) }

    let(:dns_encoder) do
      DnsEncoder.new(
        {
          {
            group_type: Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP,
            group_name: 'instance1',
            deployment: 'test-deployment',
          } => '1',
          {
            group_type: Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP,
            group_name: 'instance4',
            deployment: 'test-deployment',
          } => '4',
          {
            group_type: Models::LocalDnsEncodedGroup::Types::INSTANCE_GROUP,
            group_name: 'instance2',
            deployment: 'test-deployment',
          } => '2',
          {
            group_type: Models::LocalDnsEncodedGroup::Types::LINK,
            group_name: 'link-1',
            deployment: 'test-deployment',
          } => '10',
          {
            group_type: Models::LocalDnsEncodedGroup::Types::LINK,
            group_name: 'fooname-bartype',
            deployment: 'test-deployment',
          } => '11',
        },
        {
          'az1' => '1',
          'az2' => '2',
        },
      )
    end
    let(:blobstore) { instance_double(Bosh::Blobstore::S3cliBlobstoreClient) }
    let(:domain_name) { 'fake-domain-name' }
    let(:agent_broadcaster) { instance_double(AgentBroadcaster) }

    let(:deployment) { FactoryBot.create(:models_deployment, name: 'test-deployment') }

    let(:include_index_records) { false }
    let(:instance1) { Models::Instance.make(uuid: 'uuid1', index: 1) }

    before do
      Models::LocalDnsEncodedNetwork.make(id: 1, name: 'net-name1')
      Models::LocalDnsEncodedNetwork.make(id: 2, name: 'net-name2')
      Models::LocalDnsEncodedNetwork.make(id: 3, name: 'net-name3')
      allow(Config).to receive(:root_domain).and_return(domain_name)
      allow(Config).to receive(:local_dns_include_index?).and_return(false)
      allow(agent_broadcaster).to receive(:sync_dns)
      allow(agent_broadcaster).to receive(:filter_instances)
      allow(Bosh::Director::LocalDnsEncoderManager).to receive(:create_dns_encoder).and_return(dns_encoder)
    end

    describe 'publish and broadcast' do
      let!(:original_local_dns_blob) { Models::LocalDnsBlob.make }

      let(:instance2) do
        Models::Instance.make(
          uuid: 'uuid2',
          index: 2,
        )
      end

      before do
        Bosh::Director::Models::LocalDnsRecord.make(
          instance_id: instance1.id,
          ip: '192.0.2.101',
          deployment: 'test-deployment',
          az: 'az1',
          instance_group: 'instance1',
          network: 'net-name1',
          agent_id: 'fake-agent-uuid1',
          domain: 'fake-domain-name',
        )

        Bosh::Director::Models::LocalDnsRecord.make(
          instance_id: instance1.id,
          ip: '192.0.3.101',
          deployment: 'test-deployment',
          az: 'az1',
          instance_group: 'instance1',
          network: 'net-name3',
          agent_id: 'fake-agent-uuid1',
          domain: 'fake-domain-name',
        )

        Bosh::Director::Models::LocalDnsRecord.make(
          instance_id: instance2.id,
          ip: '192.0.2.102',
          deployment: 'test-deployment',
          az: 'az2',
          instance_group: 'instance2',
          network: 'net-name2',
          agent_id: 'fake-agent-uuid2',
          domain: 'fake-domain-name',
          links: [{ name: 'link-1' }],
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

        context 'and there are aliases in the link providers' do
          before do
            deployment = Models::Deployment.create(name: 'test-deployment')
            Models::LocalDnsAlias.create(
              deployment: deployment,
              domain: 'my-link-provider.domain',
              health_filter: 'all',
              initial_health_check: 'synchronous',
              group_id: '11',
            )
          end

          it 'adds the aliases to the record output' do
            expected_records = {
              'aliases' => {
                'my-link-provider.domain' => [
                  {
                    'root_domain' => 'fake-domain-name',
                    'health_filter' => 'all',
                    'initial_health_check' => 'synchronous',
                    'group_id' => '11',
                    'placeholder_type' => nil,
                  },
                ],
              },
            }
            expect(blobstore).to receive(:create) do |actual_records_json|
              actual_records = JSON.parse(actual_records_json)
              expect(actual_records).to include(expected_records)
            end
            dns.publish_and_broadcast
          end
        end

        it 'puts a blob containing the records into the blobstore' do
          previous_version = Bosh::Director::Models::LocalDnsBlob.last.version
          expected_records = {
            'records' => [
              ['192.0.2.101', 'uuid1.instance1.net-name1.test-deployment.fake-domain-name'],
              ['192.0.3.101', 'uuid1.instance1.net-name3.test-deployment.fake-domain-name'],
              ['192.0.2.102', 'uuid2.instance2.net-name2.test-deployment.fake-domain-name'],
            ],
            'version' => be > previous_version,
            'aliases' => {},
            'record_keys' =>
                  %w[id num_id instance_group group_ids az az_id network network_id deployment ip domain agent_id instance_index],
            'record_infos' => [
              [
                'uuid1',
                instance1.id.to_s,
                'instance1',
                ['1'],
                'az1',
                '1',
                'net-name1',
                '1',
                'test-deployment',
                '192.0.2.101',
                'fake-domain-name',
                'fake-agent-uuid1',
                1,
              ],
              [
                'uuid1',
                instance1.id.to_s,
                'instance1',
                ['1'],
                'az1',
                '1',
                'net-name3',
                '3',
                'test-deployment',
                '192.0.3.101',
                'fake-domain-name',
                'fake-agent-uuid1',
                1,
              ],
              [
                'uuid2',
                instance2.id.to_s,
                'instance2',
                %w[2 10],
                'az2',
                '2',
                'net-name2',
                '2',
                'test-deployment',
                '192.0.2.102',
                'fake-domain-name',
                'fake-agent-uuid2',
                2,
              ],
            ],
          }
          expect(blobstore).to receive(:create) do |actual_records_json|
            actual_records = JSON.parse(actual_records_json)
            version_matcher = expected_records.delete('version')
            actual_version = actual_records.delete('version')
            expect(actual_records).to eq(expected_records)
            expect(actual_version).to version_matcher
            'blob_id_1'
          end
          dns.publish_and_broadcast
        end

        it 'creates a model representing the blob' do
          previous_version = Bosh::Director::Models::LocalDnsBlob.last.version
          dns.publish_and_broadcast
          local_dns_blob = Bosh::Director::Models::LocalDnsBlob.last
          expected_records_version = Bosh::Director::Models::LocalDnsRecord.max(:id)

          expect(local_dns_blob.blob.blobstore_id).to eq('blob_id_1')
          expect(local_dns_blob.version).to be > previous_version
          expect(local_dns_blob.records_version).to eq(expected_records_version)
        end

        it 'broadcasts the blob to the agents' do
          previous_version = Bosh::Director::Models::LocalDnsBlob.last.version
          dns.publish_and_broadcast
          expect(agent_broadcaster).to receive(:filter_instances).with(nil).and_return([])
          expect(agent_broadcaster).to receive(:sync_dns).with([], 'blob_id_1', /[a-z0-9]{40}/, be > previous_version)
          dns.publish_and_broadcast
        end

        context 'when the root_domain is empty' do
          let!(:instance3) do
            Models::Instance.make(
              uuid: 'uuid3',
              index: 3,
            )
          end

          before do
            Bosh::Director::Models::LocalDnsRecord.make(
              instance_id: instance3.id,
              ip: '192.0.2.104',
              deployment: 'test-deployment',
              az: 'az2',
              instance_group: 'instance4',
              network: 'net-name2',
              agent_id: 'fake-agent-uuid4',
            )
          end

          it 'backfills the current root_domain' do
            previous_version = Bosh::Director::Models::LocalDnsBlob.last.version
            expected_records = {
              'records' => [
                ['192.0.2.101', 'uuid1.instance1.net-name1.test-deployment.fake-domain-name'],
                ['192.0.3.101', 'uuid1.instance1.net-name3.test-deployment.fake-domain-name'],
                ['192.0.2.102', 'uuid2.instance2.net-name2.test-deployment.fake-domain-name'],
                ['192.0.2.104', 'uuid3.instance4.net-name2.test-deployment.fake-domain-name'],
              ],
              'aliases' => {},
              'version' => be > previous_version,
              'record_keys' =>
                %w[id num_id instance_group group_ids az az_id network network_id deployment ip domain agent_id instance_index],
              'record_infos' => [
                [
                  'uuid1',
                  instance1.id.to_s,
                  'instance1',
                  ['1'],
                  'az1',
                  '1',
                  'net-name1',
                  '1',
                  'test-deployment',
                  '192.0.2.101',
                  'fake-domain-name',
                  'fake-agent-uuid1',
                  1,
                ],
                [
                  'uuid1',
                  instance1.id.to_s,
                  'instance1',
                  ['1'],
                  'az1',
                  '1',
                  'net-name3',
                  '3',
                  'test-deployment',
                  '192.0.3.101',
                  'fake-domain-name',
                  'fake-agent-uuid1',
                  1,
                ],
                [
                  'uuid2',
                  instance2.id.to_s,
                  'instance2',
                  %w[2 10],
                  'az2',
                  '2',
                  'net-name2',
                  '2',
                  'test-deployment',
                  '192.0.2.102',
                  'fake-domain-name',
                  'fake-agent-uuid2',
                  2,
                ],
                [
                  'uuid3',
                  instance3.id.to_s,
                  'instance4',
                  ['4'],
                  'az2',
                  '2',
                  'net-name2',
                  '2',
                  'test-deployment',
                  '192.0.2.104',
                  'fake-domain-name',
                  'fake-agent-uuid4',
                  3,
                ],
              ],
            }

            expect(blobstore).to receive(:create) do |actual_records_json|
              actual_records = JSON.parse(actual_records_json)
              version_matcher = expected_records.delete('version')
              actual_version = actual_records.delete('version')
              expect(actual_records).to eq(expected_records)
              expect(actual_version).to version_matcher
              'blob_id_1'
            end
            dns.publish_and_broadcast
          end
        end

        context 'when putting to the blobstore fails' do
          it 'fails uploading records' do
            expect(blobstore).to receive(:create).and_raise(Bosh::Blobstore::BlobstoreError)

            expect do
              dns.publish_and_broadcast
            end.to raise_error(Bosh::Blobstore::BlobstoreError)
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
            previous_version = Bosh::Director::Models::LocalDnsBlob.last.version
            expected_records = {
              'records' => [
                ['192.0.2.101', 'uuid1.instance1.net-name1.test-deployment.fake-domain-name'],
                ['192.0.2.101', '1.instance1.net-name1.test-deployment.fake-domain-name'],
                ['192.0.3.101', 'uuid1.instance1.net-name3.test-deployment.fake-domain-name'],
                ['192.0.3.101', '1.instance1.net-name3.test-deployment.fake-domain-name'],
                ['192.0.2.102', 'uuid2.instance2.net-name2.test-deployment.fake-domain-name'],
                ['192.0.2.102', '2.instance2.net-name2.test-deployment.fake-domain-name'],
              ],
              'version' => be > previous_version,
              'aliases' => {},
              'record_keys' =>
              %w[
                id
                num_id
                instance_group
                group_ids
                az
                az_id
                network
                network_id
                deployment
                ip
                domain
                agent_id
                instance_index
              ],
              'record_infos' => [
                [
                  'uuid1',
                  instance1.id.to_s,
                  'instance1',
                  ['1'],
                  'az1',
                  '1',
                  'net-name1',
                  '1',
                  'test-deployment',
                  '192.0.2.101',
                  'fake-domain-name',
                  'fake-agent-uuid1',
                  1,
                ],
                [
                  'uuid1',
                  instance1.id.to_s,
                  'instance1',
                  ['1'],
                  'az1',
                  '1',
                  'net-name3',
                  '3',
                  'test-deployment',
                  '192.0.3.101',
                  'fake-domain-name',
                  'fake-agent-uuid1',
                  1,
                ],
                [
                  'uuid2',
                  instance2.id.to_s,
                  'instance2',
                  %w[2 10],
                  'az2',
                  '2',
                  'net-name2',
                  '2',
                  'test-deployment',
                  '192.0.2.102',
                  'fake-domain-name',
                  'fake-agent-uuid2',
                  2,
                ],
              ],
            }

            expect(blobstore).to receive(:create) do |actual_records_json|
              actual_records = JSON.parse(actual_records_json)
              version_matcher = expected_records.delete('version')
              actual_version = actual_records.delete('version')
              expect(actual_records).to eq(expected_records)
              expect(actual_version).to version_matcher
              'blob_id_1'
            end
            dns.publish_and_broadcast
          end
        end

        context 'and aliases are added to link providers' do
          let(:deployment) do
            Models::Deployment.create(name: 'test-deployment')
          end

          it 'adds the aliases to the record output' do
            dns.publish_and_broadcast
            Models::LocalDnsAlias.create(
              deployment: deployment,
              domain: 'my-link-provider.domain',
              health_filter: 'all',
              initial_health_check: 'synchronous',
              group_id: '11',
            )

            expected_records = {
              'aliases' => {
                'my-link-provider.domain' => [
                  {
                    'root_domain' => 'fake-domain-name',
                    'health_filter' => 'all',
                    'initial_health_check' => 'synchronous',
                    'group_id' => '11',
                    'placeholder_type' => nil,
                  },
                ],
              },
            }
            expect(blobstore).to receive(:create) do |actual_records_json|
              actual_records = JSON.parse(actual_records_json)
              expect(actual_records).to include(expected_records)
            end
            dns.publish_and_broadcast
          end
        end

        context 'when the dns blobs are up to date' do
          it 'does not generate a new blob' do
            dns.publish_and_broadcast

            expect(blobstore).to_not receive(:create)
            dns.publish_and_broadcast
          end

          it 'broadcasts' do
            dns.publish_and_broadcast

            expect(agent_broadcaster).to receive(:sync_dns)
            dns.publish_and_broadcast
          end
        end
      end
    end

    describe 'publish_and_send_to_instance' do
      let!(:original_local_dns_blob) { Models::LocalDnsBlob.make }

      let(:instance2) do
        Models::Instance.make(
          uuid: 'uuid2',
          index: 2,
        )
      end

      before do
        Bosh::Director::Models::LocalDnsRecord.make(
          instance_id: instance1.id,
          ip: '192.0.2.101',
          deployment: 'test-deployment',
          az: 'az1',
          instance_group: 'instance1',
          network: 'net-name1',
          agent_id: 'fake-agent-uuid1',
          domain: 'fake-domain-name',
        )

        Bosh::Director::Models::LocalDnsRecord.make(
          instance_id: instance1.id,
          ip: '192.0.3.101',
          deployment: 'test-deployment',
          az: 'az1',
          instance_group: 'instance1',
          network: 'net-name3',
          agent_id: 'fake-agent-uuid1',
          domain: 'fake-domain-name',
        )

        Bosh::Director::Models::LocalDnsRecord.make(
          instance_id: instance2.id,
          ip: '192.0.2.102',
          deployment: 'test-deployment',
          az: 'az2',
          instance_group: 'instance2',
          network: 'net-name2',
          agent_id: 'fake-agent-uuid2',
          domain: 'fake-domain-name',
          links: [{ name: 'link-1' }],
        )

        Bosh::Director::Models::LocalDnsRecord.make(instance_id: nil, ip: 'tombstone')
      end

      context 'when local_dns is not enabled' do
        before do
          allow(Config).to receive(:local_dns_enabled?).and_return(false)
        end

        it 'does nothing' do
          expect(agent_broadcaster).to_not receive(:sync_dns)
          dns.publish_and_send_to_instance(instance1)
          expect(Models::LocalDnsBlob.last).to eq(original_local_dns_blob)
        end
      end

      context 'when local_dns is enabled' do
        before do
          allow(Config).to receive(:local_dns_enabled?).and_return(true)
          allow(blobstore).to receive(:create).and_return('blob_id_1')
        end

        it 'puts a blob containing the records into the blobstore' do
          previous_version = Bosh::Director::Models::LocalDnsBlob.last.version
          expected_records = {
            'records' => [
              ['192.0.2.101', 'uuid1.instance1.net-name1.test-deployment.fake-domain-name'],
              ['192.0.3.101', 'uuid1.instance1.net-name3.test-deployment.fake-domain-name'],
              ['192.0.2.102', 'uuid2.instance2.net-name2.test-deployment.fake-domain-name'],
            ],
            'version' => be > previous_version,
            'aliases' => {},
            'record_keys' =>
                  %w[id num_id instance_group group_ids az az_id network network_id deployment ip domain agent_id instance_index],
            'record_infos' => [
              [
                'uuid1',
                instance1.id.to_s,
                'instance1',
                ['1'],
                'az1',
                '1',
                'net-name1',
                '1',
                'test-deployment',
                '192.0.2.101',
                'fake-domain-name',
                'fake-agent-uuid1',
                1,
              ],
              [
                'uuid1',
                instance1.id.to_s,
                'instance1',
                ['1'],
                'az1',
                '1',
                'net-name3',
                '3',
                'test-deployment',
                '192.0.3.101',
                'fake-domain-name',
                'fake-agent-uuid1',
                1,
              ],
              [
                'uuid2',
                instance2.id.to_s,
                'instance2',
                %w[2 10],
                'az2',
                '2',
                'net-name2',
                '2',
                'test-deployment',
                '192.0.2.102',
                'fake-domain-name',
                'fake-agent-uuid2',
                2,
              ],
            ],
          }
          expect(blobstore).to receive(:create) do |actual_records_json|
            actual_records = JSON.parse(actual_records_json)
            version_matcher = expected_records.delete('version')
            actual_version = actual_records.delete('version')
            expect(actual_records).to eq(expected_records)
            expect(actual_version).to version_matcher
            'blob_id_1'
          end
          dns.publish_and_broadcast
        end

        it 'creates a model representing the blob' do
          previous_version = Bosh::Director::Models::LocalDnsBlob.last.version
          dns.publish_and_send_to_instance(instance1)
          local_dns_blob = Bosh::Director::Models::LocalDnsBlob.last
          expected_records_version = Bosh::Director::Models::LocalDnsRecord.max(:id)

          expect(local_dns_blob.blob.blobstore_id).to eq('blob_id_1')
          expect(local_dns_blob.version).to be > previous_version
          expect(local_dns_blob.records_version).to eq(expected_records_version)
        end

        it 'broadcasts the blob to the agents' do
          previous_version = Bosh::Director::Models::LocalDnsBlob.last.version
          dns.publish_and_send_to_instance(instance1)
          expect(agent_broadcaster).to receive(:sync_dns).with([instance1], 'blob_id_1', /[a-z0-9]{40}/, be > previous_version)
          dns.publish_and_send_to_instance(instance1)
        end
      end
    end
  end
end
