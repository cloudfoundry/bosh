require 'spec_helper'

module Bosh::Director
  describe DnsManager do
    subject(:dns_manager) { described_class.new(domain.name, dns_config, dns_provider, dns_publisher, local_dns_repo, logger) }

    let(:instance_model) do
      Models::Instance.make(
          uuid: 'fake-uuid',
          index: 0,
          job: 'job-a',
          deployment: deployment_model,
          spec_json: spec_json
      )
    end
    let(:spec_json) { '{}' }
    let(:deployment_model) { Models::Deployment.make(name: 'bosh.1') }
    let(:domain) { Models::Dns::Domain.make(name: 'bosh', type: 'NATIVE') }
    let(:dns_config) { {} }
    let(:dns_provider) { nil }
    let(:blobstore) { instance_double(Bosh::Blobstore::S3cliBlobstoreClient) }
    let(:agent_broadcaster) { instance_double(AgentBroadcaster) }
    let(:dns_publisher) { BlobstoreDnsPublisher.new(blobstore, 'fake-domain-name', agent_broadcaster, logger) }
    let(:local_dns_repo) { LocalDnsRepo.new(logger) }

    describe '#flush_dns_cache' do
      let(:dns_config) { {'domain_name' => domain.name, 'flush_command' => flush_command} }
      let(:flush_command) { nil }

      context 'when flush command is present' do
        let(:flush_command) { "echo \"7\" && exit 0" }

        it 'logs success' do
          expect(logger).to receive(:debug).with("Flushed 7 records from DNS cache")
          dns_manager.flush_dns_cache
        end
      end

      context 'when running flush command fails' do
        let(:flush_command) { "echo fake failure >&2 && exit 1" }

        it 'logs an error' do
          expect(logger).to receive(:warn).with("Failed to flush DNS cache: fake failure")
          dns_manager.flush_dns_cache
        end
      end

      context 'when flush command is not present' do
        it 'does not do anything' do
          expect(Open3).to_not receive(:capture3)
          expect {
            dns_manager.flush_dns_cache
          }.to_not raise_error
        end
      end

      context 'when dns_publisher is disabled' do
        it 'calls nothing on the dns_publisher' do
          dns_manager.flush_dns_cache
        end
      end
    end

    describe '#publish_dns_records' do
      context 'when dns_publisher is disabled' do
        it 'calls nothing on the dns_publisher' do
          dns_manager.flush_dns_cache
        end
      end
    end

    describe '#cleanup_dns_records' do
      context 'when dns_publisher is enabled' do
        let!(:old_local_dns_blob) do
          Models::LocalDnsBlob.create(
              sha1: 'old-sha1',
              blobstore_id: 'old-id',
              version: 1,
              created_at: Time.new(2016, 10, 31)
          )
        end

        let!(:latest_local_dns_blob) do
          Models::LocalDnsBlob.create(
              sha1: 'latest-sha1',
              blobstore_id: 'latest-id',
              version: 2,
              created_at: Time.new(2016, 11, 31)
          )
        end

        it 'deletes all local dns blobs except the most recent version' do
          dns_manager.cleanup_dns_records
          expect(Models::LocalDnsBlob.all).to contain_exactly(latest_local_dns_blob)
        end
      end

      it 'does not delete any blobs' do
        expect{
          dns_manager.cleanup_dns_records
        }.to_not change { Models::LocalDnsBlob.count }
      end
    end

    describe '#find_dns_record_names_by_instance' do
      context 'instance model is not set' do
        let(:instance_model) { nil }

        it 'returns an empty list' do
          expect(dns_manager.find_dns_record_names_by_instance(instance_model)).to eq([])
        end
      end

      context 'instance model is set' do
        let(:instance_model) { Models::Instance.make(uuid: 'fake-uuid', index: 0, job: 'job-a', deployment: deployment_model, dns_records: '["test1.example.com","test2.example.com"]') }

        it 'returns an empty list' do
          expect(dns_manager.find_dns_record_names_by_instance(instance_model)).to eq(['test1.example.com', 'test2.example.com'])
        end
      end
    end

    context 'when PowerDNS is enabled' do
      let(:dns_provider) { PowerDns.new(domain.name, logger) }

      describe '#dns_enabled?' do
        it 'should be true' do
          expect(dns_manager.dns_enabled?).to eq(true)
        end
      end

      describe '#delete_dns_for_instance' do
        before do
          dns_manager.update_dns_record_for_instance(instance_model, {'fake-dns-name-1' => '1.2.3.4', 'fake-dns-name-2' => '5.6.7.8'})
        end

        it 'deletes dns records from dns provider' do
          expect(dns_provider.find_dns_record('fake-dns-name-1', '1.2.3.4')).to_not be_nil
          expect(dns_provider.find_dns_record('fake-dns-name-2', '5.6.7.8')).to_not be_nil
          dns_manager.delete_dns_for_instance(instance_model)
          expect(dns_provider.find_dns_record('fake-dns-name-1', '1.2.3.4')).to be_nil
          expect(dns_provider.find_dns_record('fake-dns-name-2', '5.6.7.8')).to be_nil
        end

        it 'deletes dns records from instance model' do
          expect(instance_model.dns_record_names.to_a).to eq(['fake-dns-name-1', 'fake-dns-name-2'])
          dns_manager.delete_dns_for_instance(instance_model)
          expect(instance_model.dns_record_names.to_a).to eq([])
        end

        context 'when instance has records in dns provider but not in instance model' do
          before do
            dns_provider.create_or_update_dns_records('fake-uuid.job-a.network-a.dep.bosh', '1.2.3.4')
          end

          it 'removes them from dns provider' do
            dns_manager.delete_dns_for_instance(instance_model)
            expect(dns_provider.find_dns_record('0.job-a.network-a.dep.bosh', '1.2.3.4')).to be_nil
          end
        end

        context 'local dns records' do
          before do
            Models::LocalDnsRecord.create(
                                      ip: 'ip-addr',
                                      instance_id: instance_model.id
            )
          end

          it 'deletes the local dns records' do
            dns_manager.delete_dns_for_instance(instance_model)
            expect(Models::LocalDnsRecord.where(instance_id: instance_model.id).all).to be_empty
          end
        end
      end

      describe '#configure_nameserver' do
        context 'dns is enabled' do
          let(:dns_config) { {'domain_name' => domain.name, 'address' => '1.2.3.4'} }
          it 'creates name server records' do
            dns_manager.configure_nameserver
            ns_record = Models::Dns::Record.find(name: 'bosh', type: 'NS')
            a_record = Models::Dns::Record.find(type: 'A')
            soa_record = Models::Dns::Record.find(name: 'bosh', type: 'SOA')
            domain = Models::Dns::Domain.find(name: 'bosh', type: 'NATIVE')
            expect(ns_record.content).to eq('ns.bosh')
            expect(a_record.content).to eq('1.2.3.4')
            expect(soa_record.content).to eq(PowerDns::SOA)
            expect(domain).to_not eq(nil)
          end
        end
      end

      describe '#update_dns_record_for_instance' do
        let(:spec_json) { JSON.dump({'networks' => {'net-name' => {'ip' => '1234'}}}) }
        before do
          instance_model.update(availability_zone: 'az1')
          dns_manager.update_dns_record_for_instance(instance_model, {'fake-dns-name-1' => '1.2.3.4', 'fake-dns-name-2' => '5.6.7.8'})
        end

        it 'updates local dns records' do
          expect(Models::LocalDnsRecord.where(instance_id: instance_model.id).count).to eq(1)
          local_dns_record = Models::LocalDnsRecord.where(instance_id: instance_model.id).first
          expect(local_dns_record.ip).to eq('1234')
          expect(local_dns_record.az).to eq('az1')
          expect(local_dns_record.network).to eq('net-name')
          expect(local_dns_record.deployment).to eq('bosh.1')
          expect(local_dns_record.instance_group).to eq('job-a')
        end

        it 'updates dns records for instance in database' do
          expect(instance_model.dns_record_names).to eq(['fake-dns-name-1', 'fake-dns-name-2'])
          dns_manager.update_dns_record_for_instance(instance_model, {'fake-dns-name-3' => '9.8.7.6'})
          expect(instance_model.dns_record_names).to eq(['fake-dns-name-1', 'fake-dns-name-2', 'fake-dns-name-3'])
        end

        it 'appends the records to the model' do
          expect(instance_model.dns_record_names).to eq(['fake-dns-name-1', 'fake-dns-name-2'])
          dns_manager.update_dns_record_for_instance(instance_model, {'another-dns-name-1' => '1.2.3.4', 'another-dns-name-2' => '5.6.7.8'})
          expect(instance_model.dns_record_names).to eq(['fake-dns-name-1', 'fake-dns-name-2', 'another-dns-name-1', 'another-dns-name-2'])
          expect(dns_provider.find_dns_record('fake-dns-name-1', '1.2.3.4')).to_not be_nil
          expect(dns_provider.find_dns_record('fake-dns-name-2', '5.6.7.8')).to_not be_nil
          expect(dns_provider.find_dns_record('another-dns-name-1', '1.2.3.4')).to_not be_nil
          expect(dns_provider.find_dns_record('another-dns-name-2', '5.6.7.8')).to_not be_nil
        end

        it 'it keeps old record names pointing at their original ips' do
          expect(instance_model.dns_record_names).to eq(['fake-dns-name-1', 'fake-dns-name-2'])
          dns_manager.update_dns_record_for_instance(instance_model, {'another-dns-name-1' => '1.2.3.5', 'another-dns-name-2' => '5.6.7.9'})
          expect(instance_model.dns_record_names).to eq(['fake-dns-name-1', 'fake-dns-name-2', 'another-dns-name-1', 'another-dns-name-2'])
          expect(dns_provider.find_dns_record('fake-dns-name-1', '1.2.3.4')).to_not be_nil
          expect(dns_provider.find_dns_record('fake-dns-name-2', '5.6.7.8')).to_not be_nil
          expect(dns_provider.find_dns_record('another-dns-name-1', '1.2.3.5')).to_not be_nil
          expect(dns_provider.find_dns_record('another-dns-name-2', '5.6.7.9')).to_not be_nil
        end

        context 'when the dns entry already exists' do
          it 'updates the DNS record when the IP address has changed' do
            dns_manager.update_dns_record_for_instance(instance_model, {'fake-dns-name-2' => '9.8.7.6'})

            dns_record = Models::Dns::Record.find(name: 'fake-dns-name-2')
            expect(dns_record.content).to eq('9.8.7.6')
          end

          it 'does NOT update the DNS record when the IP address is the same' do
            dns_manager.update_dns_record_for_instance(instance_model, {'fake-dns-name-2' => '5.6.7.8'})

            dns_record = Models::Dns::Record.find(name: 'fake-dns-name-2')
            expect(dns_record.content).to eq('5.6.7.8')
          end
        end
      end

      describe '#migrate_legacy_records' do
        before do
          dns_provider.create_or_update_dns_records('0.job-a.network-a.bosh1.bosh', '1.2.3.4')
          dns_provider.create_or_update_dns_records('fake-uuid.job-a.network-a.bosh1.bosh', '1.2.3.4')
          dns_provider.create_or_update_dns_records('0.job-a.network-b.bosh1.bosh', '5.6.7.8')
          dns_provider.create_or_update_dns_records('fake-uuid.job-a.network-b.bosh1.bosh', '5.6.7.8')
        end

        it 'saves instance dns records for all networks in local instance model' do
          expect(instance_model.dns_record_names).to be_nil

          dns_manager.migrate_legacy_records(instance_model)

          expect(instance_model.dns_record_names).to match_array([
            '0.job-a.network-a.bosh1.bosh',
            'fake-uuid.job-a.network-a.bosh1.bosh',
            '0.job-a.network-b.bosh1.bosh',
            'fake-uuid.job-a.network-b.bosh1.bosh'
          ])
        end

        context 'when instance model has dns records' do
          before do
            instance_model.update(dns_record_names: ['anything'])
          end

          it 'does not migrate' do
            dns_manager.migrate_legacy_records(instance_model)
            expect(instance_model.dns_record_names).to match_array(['anything'])
          end
        end
      end
    end

    context 'when PowerDNS is disabled' do
      let(:instance_model) { Models::Instance.make(uuid: 'fake-uuid', index: 0, job: 'job-a', deployment: deployment_model) }

      describe '#dns_enabled?' do
        it 'should be false' do
          expect(dns_manager.dns_enabled?).to eq(false)
        end
      end

      describe '#delete_dns_for_instance' do
        it 'returns with no errors' do
          dns_manager.delete_dns_for_instance(instance_model)
        end
      end

      describe '#migrate_legacy_records' do
        it 'does not migrate' do
          dns_manager.migrate_legacy_records(instance_model)
          expect(instance_model.dns_record_names.to_a).to match_array([])
        end
      end

      describe '#configure_nameserver' do
        it 'creates nothing' do
          dns_manager.configure_nameserver
          ns_record = Models::Dns::Record.find(name: domain.name, type: 'NS')
          a_record = Models::Dns::Record.find(type: 'A')
          soa_record = Models::Dns::Record.find(name: domain.name, type: 'SOA')
          expect(ns_record).to eq(nil)
          expect(a_record).to eq(nil)
          expect(soa_record).to eq(nil)
        end
      end

      describe '#update_dns_record_for_instance' do
        before do
          dns_manager.update_dns_record_for_instance(instance_model, {'fake-dns-name-1' => '1.2.3.4', 'fake-dns-name-2' => '5.6.7.8'})
        end

        context 'when IPs/hosts change' do
          it 'updates dns records for instance' do
            expect(instance_model.dns_record_names).to eq(['fake-dns-name-1', 'fake-dns-name-2'])
            dns_manager.update_dns_record_for_instance(instance_model, {'fake-dns-name-1' => '11.22.33.44', 'new-fake-dns-name' => '99.88.77.66'})
            expect(instance_model.dns_record_names).to eq(['fake-dns-name-1', 'fake-dns-name-2', 'new-fake-dns-name'])
            expect(Models::Dns::Record.all.count).to eq(0)
          end
        end
      end
    end

    describe 'find_local_dns_record' do
      let(:spec_json) { '{"networks":{"name":{"ip":"1234"}},"job":{"name":"job_name"},"deployment":"bosh"}' }

      before do
        subject.update_dns_record_for_instance(instance_model, {})
      end

      it 'should call create_or_delete_local_dns_record to add UUID and Index based DNS record' do
        expect(subject.find_local_dns_record(instance_model)).to eq(Models::LocalDnsRecord.where(instance_id: instance_model.id).all)
      end
    end
  end
end
