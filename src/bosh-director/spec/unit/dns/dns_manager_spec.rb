require 'spec_helper'

module Bosh::Director
  describe DnsManager do
    subject(:dns_manager) { described_class.new(domain.name, dns_config, dns_provider, dns_publisher, logger) }

    let(:instance_model) { Models::Instance.make(uuid: 'fake-uuid', index: 0, job: 'job-a', deployment: deployment_model) }
    let(:deployment_model) { Models::Deployment.make(name: 'bosh.1') }
    let(:domain) { Models::Dns::Domain.make(name: 'bosh', type: 'NATIVE') }
    let(:dns_config) { {} }
    let(:dns_provider) { nil }
    let(:blobstore) { instance_double(Bosh::Blobstore::S3cliBlobstoreClient) }
    let(:dns_publisher) { BlobstoreDnsPublisher.new(blobstore, 'fake-domain-name') }

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
        it 'calls cleanup_blobs and publish on the dns_publisher' do
          expect(dns_publisher).to receive(:cleanup_blobs).and_return([])
          dns_manager.cleanup_dns_records
        end
      end

      context 'when dns_publisher is disabled' do
        it 'calls nothing on the dns_publisher' do
          dns_manager.cleanup_dns_records
        end
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

        it 'calls the local dns methods' do
          expect(dns_manager).to receive(:delete_local_dns_record).with(instance_model)
          dns_manager.delete_dns_for_instance(instance_model)
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
        before do
          dns_manager.update_dns_record_for_instance(instance_model, {'fake-dns-name-1' => '1.2.3.4', 'fake-dns-name-2' => '5.6.7.8'})
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

        it 'deletes old records and creates a new dns record' do
          expect(dns_manager).to receive(:create_or_delete_local_dns_record)
          dns_manager.update_dns_record_for_instance(instance_model, {'another-dns-name-1' => '1.2.3.4', 'another-dns-name-2' => '5.6.7.8'})
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

    describe '#create_or_delete_local_dns_record' do
      it 'creates canonicalized records' do
        instance_model.update(
          index: 0,
          availability_zone: 'az-1',
          job: 'job_Name',
          spec_json: '{"networks":[["net-name",{"ip":"1234"}]],"job":{"name":"job_Name"},"deployment":"bosh.1"}'
        )

        subject.create_or_delete_local_dns_record(instance_model)

        local_dns_record_first = Models::LocalDnsRecord.where(instance_id: instance_model.id).all[0]
        expect(local_dns_record_first.name).to eq('fake-uuid.job-name.net-name.bosh1.bosh')
        expect(local_dns_record_first.az).to eq('az-1')
        expect(local_dns_record_first.instance_group).to eq('job_Name')
        expect(local_dns_record_first.deployment).to eq('bosh.1')
        expect(local_dns_record_first.network).to eq('net-name')
      end

      context 'when include_index enabled' do
        before do
          allow(Config).to receive(:local_dns_include_index?).and_return(true)
        end

        it 'should call create_or_delete_local_dns_record to add UUID and Index based DNS record' do
          instance_model.update(
            index: 0,
            availability_zone: 'az-1',
            job: 'job_Name',
            spec_json: '{"networks":[["net-name",{"ip":"1234"}]],"job":{"name":"job_Name"},"deployment":"bosh.1"}'
          )

          subject.create_or_delete_local_dns_record(instance_model)

          local_dns_record_first = Models::LocalDnsRecord.where(instance_id: instance_model.id).all[0]
          local_dns_record_second = Models::LocalDnsRecord.where(instance_id: instance_model.id).all[1]

          expect(local_dns_record_first.name).to match(Regexp.compile("#{instance_model.uuid}.job-name.*"))
          expect(local_dns_record_second.name).to match(Regexp.compile("#{instance_model.index}.job-name.*"))

          local_dns_record_first = Models::LocalDnsRecord.where(instance_id: instance_model.id).all[0]
          expect(local_dns_record_first.name).to eq('fake-uuid.job-name.net-name.bosh1.bosh')
          expect(local_dns_record_first.az).to eq('az-1')
          expect(local_dns_record_first.instance_group).to eq('job_Name')
          expect(local_dns_record_first.deployment).to eq('bosh.1')
          expect(local_dns_record_first.network).to eq('net-name')

          local_dns_record_second = Models::LocalDnsRecord.where(instance_id: instance_model.id).all[1]
          expect(local_dns_record_second.name).to eq('0.job-name.net-name.bosh1.bosh')
          expect(local_dns_record_second.az).to eq('az-1')
          expect(local_dns_record_second.instance_group).to eq('job_Name')
          expect(local_dns_record_second.deployment).to eq('bosh.1')
          expect(local_dns_record_second.network).to eq('net-name')

        end

        context 'when an instance is created with a new ip' do
          before do
            Models::LocalDnsRecord.make(name: 'fake-uuid.job-name.network-1.bosh1.bosh', ip: '987', instance_id: instance_model.id)
            Models::LocalDnsRecord.make(name: '0.job-name.network-1.bosh1.bosh', ip: '987', instance_id: instance_model.id)
          end

          it 'only deletes stale dns records' do
            expect(instance_model).to receive(:spec_json).and_return('{"networks":[["network-1",{"ip":"1234"}],["network-2",{"ip":"5678"}]],"job":{"name":"job_Name"},"deployment":"bosh.1"}').twice

            dns_manager.create_or_delete_local_dns_record(instance_model)

            all_records = Models::LocalDnsRecord.exclude(instance_id: nil).all
            expect(all_records.size).to eq(4)
            expect(all_records.map(&:name)).to contain_exactly('0.job-name.network-1.bosh1.bosh', 'fake-uuid.job-name.network-1.bosh1.bosh', '0.job-name.network-2.bosh1.bosh', 'fake-uuid.job-name.network-2.bosh1.bosh')
            expect(all_records.map(&:ip)).to contain_exactly('1234', '1234', '5678', '5678')
          end

          it 'should have a higher max LocalDnsRecord' do
            allow(instance_model).to receive(:spec_json).and_return('{"networks":[["network-1",{"ip":"1234"}],["network-2",{"ip":"5678"}]],"job":{"name":"job_Name"},"deployment":"bosh.1"}').twice
            expect {
              dns_manager.create_or_delete_local_dns_record(instance_model)
            }.to change { Models::LocalDnsRecord.max(:id) }.by(4)
          end
        end

        context 'when an instance is re-created with the same ip' do
          it 'should not create a duplicate dns record' do
            dns_index_id = Models::LocalDnsRecord.make(name: '0.job-name.network-1.bosh1.bosh', ip: '1234', instance_id: instance_model.id).id
            dns_uuid_id = Models::LocalDnsRecord.make(name: 'fake-uuid.job-name.network-1.bosh1.bosh', ip: '1234', instance_id: instance_model.id).id
            expect(instance_model).to receive(:spec_json).and_return('{"networks":[["network-1",{"ip":"1234"}]],"job":{"name":"job_Name"},"deployment":"bosh.1"}').twice

            expect { dns_manager.create_or_delete_local_dns_record(instance_model) }.not_to raise_error

            all_records = Models::LocalDnsRecord.all
            expect(all_records.size).to eq(2)
            expect(all_records.map(&:name)).to contain_exactly('0.job-name.network-1.bosh1.bosh', 'fake-uuid.job-name.network-1.bosh1.bosh')
            expect(all_records.map(&:ip)).to contain_exactly('1234', '1234')
            expect(all_records.map(&:id)).to contain_exactly(dns_uuid_id, dns_index_id)
          end

          it 'should not insert a tombstone record' do
            Models::LocalDnsRecord.make(name: '0.job-name.network-1.bosh1.bosh', ip: '1234', instance_id: instance_model.id).id
            Models::LocalDnsRecord.make(name: 'fake-uuid.job-name.network-1.bosh1.bosh', ip: '1234', instance_id: instance_model.id).id

            expect(instance_model).to receive(:spec_json).and_return('{"networks":[["network-1",{"ip":"1234"}]],"job":{"name":"job_Name"},"deployment":"bosh.1"}').twice
            expect { dns_manager.create_or_delete_local_dns_record(instance_model) }.not_to raise_error
            expect(Models::LocalDnsRecord.where(instance_id: nil).all.size).to eq(0)
          end
        end
      end

      context 'when include_index disabled' do
        before do
          allow(Config).to receive(:local_dns_include_index?).and_return(false)
        end

        it 'should call create_or_delete_local_dns_record to add only UUID based DNS record' do
          expect(instance_model).to receive(:spec_json).and_return('{"networks":[["name",{"ip":1234}]],"job":{"name":"job_name"},"deployment":"bosh"}').twice

          subject.create_or_delete_local_dns_record(instance_model)

          local_dns_record_first = Models::LocalDnsRecord.where(instance_id: instance_model.id).all[0]
          expect(local_dns_record_first.name).to match(Regexp.compile("#{instance_model.uuid}.job-name.*"))
        end

        context 'when an instance is created with a new ip' do
          before do
            Models::LocalDnsRecord.make(name: 'fake-uuid.job-name.network-1.bosh1.bosh', instance_id: instance_model.id, ip: '987')
            Models::LocalDnsRecord.make(name: '0.job-name.network-1.bosh1.bosh', instance_id: instance_model.id, ip: '1234')
          end

          it 'only deletes stale dns records' do
            expect(instance_model).to receive(:spec_json).and_return('{"networks":[["network-1",{"ip":"1234"}],["network-2",{"ip":"5678"}]],"job":{"name":"job_Name"},"deployment":"bosh.1"}').twice

            dns_manager.create_or_delete_local_dns_record(instance_model)

            all_records = Models::LocalDnsRecord.exclude(instance_id: nil).all
            # product says it is okay to keep index-based dns around if they previously had it enabled, but then
            # disabled it
            expect(all_records.size).to eq(3)
            expect(all_records.map(&:name).sort).to contain_exactly('fake-uuid.job-name.network-1.bosh1.bosh', '0.job-name.network-1.bosh1.bosh', 'fake-uuid.job-name.network-2.bosh1.bosh')
            expect(all_records.map(&:ip).sort).to contain_exactly('1234', '1234', '5678')
          end

          it 'should have a higher max LocalDnsRecord' do
            allow(instance_model).to receive(:spec_json).and_return('{"networks":[["network-1",{"ip":"1234"}],["network-2",{"ip":"5678"}]],"job":{"name":"job_Name"},"deployment":"bosh.1"}').twice
            expect {
              dns_manager.create_or_delete_local_dns_record(instance_model)
            }.to change { Models::LocalDnsRecord.max(:id) }.by(2)
          end
        end

        context 'when an instance is re-created with the same ip' do
          it 'should not create a duplicate dns record' do
            dns_uuid_id = Models::LocalDnsRecord.make(name: 'fake-uuid.job-name.network-1.bosh1.bosh', ip: '1234', instance_id: instance_model.id).id
            dns_index_id = Models::LocalDnsRecord.make(name: '0.job-name.network-1.bosh1.bosh', ip: '1234', instance_id: instance_model.id).id
            expect(instance_model).to receive(:spec_json).and_return('{"networks":[["network-1",{"ip":"1234"}]],"job":{"name":"job_Name"},"deployment":"bosh.1"}').twice

            expect { dns_manager.create_or_delete_local_dns_record(instance_model) }.not_to raise_error

            all_records = Models::LocalDnsRecord.all
            expect(all_records.size).to eq(2)
            expect(all_records.map(&:name)).to contain_exactly('fake-uuid.job-name.network-1.bosh1.bosh', '0.job-name.network-1.bosh1.bosh')
            expect(all_records.map(&:ip)).to contain_exactly('1234', '1234')
            expect(all_records.map(&:id)).to contain_exactly(dns_uuid_id, dns_index_id)

          end

          it 'should not insert a tombstone record' do
            Models::LocalDnsRecord.make(name: 'fake-uuid.job-name.network-1.bosh1.bosh', ip: '1234', instance_id: instance_model.id).id
            Models::LocalDnsRecord.make(name: '0.job-name.network-1.bosh1.bosh', ip: '1234', instance_id: instance_model.id).id
            expect(instance_model).to receive(:spec_json).and_return('{"networks":[["network-1",{"ip":"1234"}]],"job":{"name":"job_Name"},"deployment":"bosh.1"}').twice

            expect { dns_manager.create_or_delete_local_dns_record(instance_model) }.not_to raise_error
            expect(Models::LocalDnsRecord.where(instance_id: nil).all.size).to eq(0)
          end
        end
      end

      context 'when instance spec is invalid' do
        context 'when instance.spec is nil' do
          it 'skips the instance' do
            test_validate_spec('{}')
          end
        end

        context 'when instance.spec is not nil' do
          context 'when spec[networks] is nil' do
            it 'skips the instance' do
              test_validate_spec('{"networks": null}')
            end
          end

          context 'when spec[networks] is not nil' do
            context 'when network[ip] is nil' do
              it 'skips the instance' do
                test_validate_spec('{"networks":[["name",{}]],"job":{"name":"job_name"},"deployment":"bosh"}')
              end
            end
          end

          context 'when spec[job] is nil' do
            it 'skips the instance' do
              test_validate_spec('{"networks":[["name",{"ip":1234}]],"job":null,"deployment":"bosh"}')
            end
          end
        end

        def test_validate_spec(spec_json)
          expect(instance_model).to receive(:spec_json).and_return(spec_json).twice
          expect(Bosh::Director::Models::LocalDnsRecord).to_not receive(:create)

          subject.create_or_delete_local_dns_record(instance_model)
        end
      end
    end

    describe '#delete_local_dns_record' do
      let(:record) { instance_double(Models::LocalDnsRecord) }
      let(:expected_uuid_model) do
        {
          name: "fake-uuid.job-name.name.bosh.bosh",
          ip: '1234',
          instance_id: instance_model.id
        }
      end
      let(:expected_index_model) do
        {
          name: "0.job-name.name.bosh.bosh",
          ip: '1234',
          instance_id: instance_model.id
        }
      end

      before do
        allow(record).to receive(:delete)
      end

      it 'should search for canonicalized records' do
        expect(Models::LocalDnsRecord).to receive(:where).
          with(instance_id: instance_model.id).
          and_return(record)

        subject.delete_local_dns_record(instance_model)
      end

      context 'when the record exists' do
        it 'should insert a tombstone record' do
          instance_model_to_be_deleted = Models::Instance.make(uuid: 'a-different-fake-uuid', index: 1, job: 'job-a', deployment: deployment_model)
          Models::LocalDnsRecord.make({
            name: "a-different-fake-uuid.job-name.name.bosh.bosh",
            ip: '1234',
            instance_id: instance_model_to_be_deleted.id
          })

          subject.delete_local_dns_record(instance_model_to_be_deleted)
          tombstones = Models::LocalDnsRecord.where(instance_id: nil).all
          expect(tombstones.size).to eq(1)
        end
      end

      context 'when the record does not exists' do
        let(:instance_model) { instance_double(Models::Instance, id: 8475) }

        it 'should not insert a tombstone record' do
          subject.delete_local_dns_record(instance_model)
          tombstones = Models::LocalDnsRecord.where(instance_id: nil).all
          expect(tombstones.size).to eq(0)
        end
      end

      context 'when include_index enabled' do
        before do
          allow(Config).to receive(:local_dns_include_index?).and_return(true)
        end

        it 'should call delete_local_dns_record to remove UUID and Index based DNS record' do
          instance_model_not_to_be_deleted = Models::Instance.make(uuid: 'a-different-fake-uuid', index: 1, job: 'job-a', deployment: deployment_model)
          Models::LocalDnsRecord.make({
            name: "a-different-fake-uuid.job-name.name.bosh.bosh",
            ip: '1234',
            instance_id: instance_model_not_to_be_deleted.id
          })
          Models::LocalDnsRecord.make(expected_uuid_model)
          Models::LocalDnsRecord.make(expected_index_model)

          subject.delete_local_dns_record(instance_model)

          expect(Models::LocalDnsRecord.exclude(instance_id: nil).all.size).to eq(1)
          expect(Models::LocalDnsRecord.first.instance_id).to eq(instance_model_not_to_be_deleted.id)
        end
      end

      context 'when include_index disabled' do
        before do
          allow(Config).to receive(:local_dns_include_index?).and_return(false)
        end

        it 'should call create_or_delete_local_dns_record to add only UUID based DNS record' do
          expect(Models::LocalDnsRecord).to receive(:where).
            with(instance_id: instance_model.id).
            and_return(record)

          subject.delete_local_dns_record(instance_model)
        end
      end
    end

    describe 'find_local_dns_record' do
      context 'when include_index enabled' do
        before do
          allow(Config).to receive(:local_dns_include_index?).and_return(true)
          allow(instance_model).to receive(:spec_json).and_return('{"networks":[["name",{"ip":1234}]],"job":{"name":"job_name"},"deployment":"bosh"}').twice

          subject.create_or_delete_local_dns_record(instance_model)
        end

        it 'should call create_or_delete_local_dns_record to add UUID and Index based DNS record' do
          expect(instance_model).to receive(:spec_json).and_return('{"networks":[["name",{"ip":"1234"}]],"job":{"name":"job_name"},"deployment":"bosh"}').twice

          local_dns_record_first = Models::LocalDnsRecord.where(instance_id: instance_model.id).all[0]
          local_dns_record_second = Models::LocalDnsRecord.where(instance_id: instance_model.id).all[1]

          expect(subject.find_local_dns_record(instance_model)).
            to include(local_dns_record_first, local_dns_record_second)
        end
      end
    end
  end
end
