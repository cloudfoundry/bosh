require 'spec_helper'

module Bosh::Director
  describe DnsManager do
    let(:instance_model) { Models::Instance.make(uuid: 'fake-uuid', index: 0, job: 'job-a', deployment: deployment_model) }
    let(:deployment_model) { Models::Deployment.make(name:'dep') }
    let(:local_dns_repo) { LocalDnsRepo.new(logger) }
    let(:domain) { Models::Dns::Domain.make(name: 'bosh', type: 'NATIVE') }

    describe EnabledDnsManager do
      subject(:dns_manager) { described_class.new(domain.name, dns_config, dns_provider, local_dns_repo, logger) }
      let(:dns_provider) { PowerDns.new(domain.name, logger) }
      let(:dns_config) { {} }

      describe '#flush_dns_cache' do
        let(:dns_config) { {'domain_name' => domain.name, 'flush_command' => flush_command} }

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
          let(:flush_command) { nil }

          it 'does not do anything' do
            expect(Open3).to_not receive(:capture3)
            expect {
              dns_manager.flush_dns_cache
            }.to_not raise_error
          end
        end
      end

      describe '#delete_dns_for_instance' do
        before do
          dns_manager.update_dns_record_for_instance(instance_model, {'fake-dns-name-1' => '1.2.3.4','fake-dns-name-2' => '5.6.7.8'})
        end

        it 'deletes dns records from dns provider' do
          expect(dns_provider.find_dns_record('fake-dns-name-1', '1.2.3.4')).to_not be_nil
          expect(dns_provider.find_dns_record('fake-dns-name-2', '5.6.7.8')).to_not be_nil
          dns_manager.delete_dns_for_instance(instance_model)
          expect(dns_provider.find_dns_record('fake-dns-name-1', '1.2.3.4')).to be_nil
          expect(dns_provider.find_dns_record('fake-dns-name-2', '5.6.7.8')).to be_nil
        end

        it 'deletes dns records from local repo' do
          expect(local_dns_repo.find(instance_model)).to eq(['fake-dns-name-1','fake-dns-name-2'])
          dns_manager.delete_dns_for_instance(instance_model)
          expect(local_dns_repo.find(instance_model)).to eq([])
        end

        context 'when instance has records in dns provider but not in local repo' do
          before do
            dns_provider.create_or_update_dns_records('fake-uuid.job-a.network-a.dep.bosh', '1.2.3.4')
          end

          it 'removes them from dns provider' do
            dns_manager.delete_dns_for_instance(instance_model)
            expect(dns_provider.find_dns_record('0.job-a.network-a.dep.bosh', '1.2.3.4')).to be_nil
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

      describe '#dns_servers' do
        it 'should return nil when there are no DNS servers' do
          expect(dns_manager.dns_servers('network', nil)).to be_nil
        end

        it 'should return an array of DNS servers' do
          expect(dns_manager.dns_servers('network', %w[1.2.3.4 5.6.7.8])).to eq(%w[1.2.3.4 5.6.7.8])
        end

        it "should raise an error if a DNS server isn't specified with as an IP" do
          expect {
            dns_manager.dns_servers('network', %w[1.2.3.4 foo.bar])
          }.to raise_error
        end

        context 'when there is a default server' do
          let(:dns_config) { {'domain_name' => domain.name, 'server' => '9.10.11.12'} }

          it 'should add default dns server when there are no DNS servers' do
            expect(dns_manager.dns_servers('network', [])).to eq(%w[9.10.11.12])
          end

          it 'should add default dns server to an array of DNS servers' do
            expect(dns_manager.dns_servers('network', %w[1.2.3.4 5.6.7.8])).to eq(%w[1.2.3.4 5.6.7.8 9.10.11.12])
          end

          it 'should not add default dns server to an array of DNS servers' do
            expect(dns_manager.dns_servers('network', %w[1.2.3.4 5.6.7.8], false)).to eq(%w[1.2.3.4 5.6.7.8])
          end

          it 'should add default dns server to an array of DNS servers' do
            expect(dns_manager.dns_servers('network', %w[1.2.3.4 5.6.7.8])).to eq(%w[1.2.3.4 5.6.7.8 9.10.11.12])
          end

          it 'should not add default dns server if already set' do
            expect(dns_manager.dns_servers('network', %w[1.2.3.4 9.10.11.12])).to eq(%w[1.2.3.4 9.10.11.12])
          end

          context 'when dns server is 127.0.0.1' do
            let(:dns_config) { {'domain_name' => domain.name, 'server' => '127.0.0.1'} }

            it 'should not add default dns server if it is 127.0.0.1' do
              expect(dns_manager.dns_servers('network', %w[1.2.3.4])).to eq(%w[1.2.3.4])
            end
          end
        end
      end

      describe '#update_dns_record_for_instance' do
        before do
          dns_manager.update_dns_record_for_instance(instance_model, {'fake-dns-name-1' => '1.2.3.4','fake-dns-name-2' => '5.6.7.8'})
        end

        it 'updates dns records for instance in local repo' do
          expect(local_dns_repo.find(instance_model)).to eq(['fake-dns-name-1','fake-dns-name-2'])
          dns_manager.update_dns_record_for_instance(instance_model, {'fake-dns-name-3' => '9.8.7.6'})
          expect(local_dns_repo.find(instance_model)).to eq(['fake-dns-name-1','fake-dns-name-2', 'fake-dns-name-3'])
        end

        it 'appends the records to the model' do
          expect(instance_model.dns_record_names).to eq(['fake-dns-name-1', 'fake-dns-name-2'])
          dns_manager.update_dns_record_for_instance(instance_model, {'another-dns-name-1' => '1.2.3.4','another-dns-name-2' => '5.6.7.8'})
          expect(instance_model.dns_record_names).to eq(['fake-dns-name-1', 'fake-dns-name-2', 'another-dns-name-1', 'another-dns-name-2'])
          expect(dns_provider.find_dns_record('fake-dns-name-1', '1.2.3.4')).to_not be_nil
          expect(dns_provider.find_dns_record('fake-dns-name-2', '5.6.7.8')).to_not be_nil
          expect(dns_provider.find_dns_record('another-dns-name-1', '1.2.3.4')).to_not be_nil
          expect(dns_provider.find_dns_record('another-dns-name-2', '5.6.7.8')).to_not be_nil
        end

        it 'it keeps old record names pointing at their original ips' do
          expect(instance_model.dns_record_names).to eq(['fake-dns-name-1', 'fake-dns-name-2'])
          dns_manager.update_dns_record_for_instance(instance_model, {'another-dns-name-1' => '1.2.3.5','another-dns-name-2' => '5.6.7.9'})
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
          dns_provider.create_or_update_dns_records('0.job-a.network-a.dep.bosh', '1.2.3.4')
          dns_provider.create_or_update_dns_records('fake-uuid.job-a.network-a.dep.bosh', '1.2.3.4')
          dns_provider.create_or_update_dns_records('0.job-a.network-b.dep.bosh', '5.6.7.8')
          dns_provider.create_or_update_dns_records('fake-uuid.job-a.network-b.dep.bosh', '5.6.7.8')
        end

        it 'saves instance dns records for all networks in local repo' do
          dns_manager.migrate_legacy_records(instance_model)

          expect(local_dns_repo.find(instance_model)).to match_array([
                '0.job-a.network-a.dep.bosh',
                'fake-uuid.job-a.network-a.dep.bosh',
                '0.job-a.network-b.dep.bosh',
                'fake-uuid.job-a.network-b.dep.bosh'
              ])
        end


        context 'when local repo has dns records' do
          before do
            local_dns_repo.create_or_update(instance_model, ['anything'])
          end

          it 'does not migrate' do
            dns_manager.migrate_legacy_records(instance_model)
            expect(local_dns_repo.find(instance_model)).to match_array(['anything'])
          end
        end
      end
    end

    describe DisabledDnsManager do
      subject(:dns_manager) { described_class.new }
      let(:instance_model) { Models::Instance.make(uuid: 'fake-uuid', index: 0, job: 'job-a', deployment: deployment_model) }

      describe '#migrate_legacy_records' do
        it 'does not migrate' do
          dns_manager.migrate_legacy_records(instance_model)
          expect(local_dns_repo.find(instance_model)).to match_array([])
        end
      end


      describe '#dns_servers' do
        it 'should not add default dns server when dns is not enabled' do
          expect(dns_manager.dns_servers('network', %w[1.2.3.4])).to eq(%w[1.2.3.4])
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
    end
  end
end
