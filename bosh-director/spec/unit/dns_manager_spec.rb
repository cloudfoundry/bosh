require 'spec_helper'

module Bosh::Director
  describe DnsManager do
    let(:dns_manager) { described_class.new(logger) }
    let(:domain) { Models::Dns::Domain.make(name: 'bosh', type: 'NATIVE') }

    before do
      allow(Config).to receive(:dns_domain_name).and_return(domain.name)
      allow(Config).to receive(:dns_enabled?).and_return(true)
    end

    describe '#flush_dns_cache' do
      before { allow(Config).to receive(:dns).and_return({'flush_command' => flush_command}) }

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

    describe '#canonical' do
      it 'should be lowercase' do
        expect(dns_manager.canonical('HelloWorld')).to eq('helloworld')
      end

      it 'should convert underscores to hyphens' do
        expect(dns_manager.canonical('hello_world')).to eq('hello-world')
      end

      it 'should strip any non alpha numeric characters' do
        expect(dns_manager.canonical('hello^world')).to eq('helloworld')
      end

      it "should reject strings that don't start with a letter or end with a letter/number" do
        expect {
          dns_manager.canonical('-helloworld')
        }.to raise_error(
            DnsInvalidCanonicalName,
            "Invalid DNS canonical name `-helloworld', must begin with a letter",
          )

        expect {
          dns_manager.canonical('helloworld-')
        }.to raise_error(
            DnsInvalidCanonicalName,
            "Invalid DNS canonical name `helloworld-', can't end with a hyphen",
          )
      end
    end

    describe '#delete_dns_for_instance' do
      let(:deployment_model) { Models::Deployment.make(name:'dep') }
      let(:instance_model) { Models::Instance.make(uuid: 'fake-uuid', index: 0, job: 'job-a', deployment: deployment_model) }

      it 'only deletes records that match the deployment, job, and index/uuid' do
        {
          '0.job-a.network-a.dep.bosh' => '1.1.1.1',
          'fake-uuid.job-a.network-a.dep.bosh' => '1.1.1.1',
          '1.job-a.network-a.dep.bosh' => '1.1.1.2',
          '0.job-b.network-b.dep.bosh' => '1.1.2.1',
          '0.job-a.network-a.dep-b.bosh' => '1.2.1.1'
        }.each do |key, value|
          Models::Dns::Record.make(domain: domain, name: key, content: value)
        end

        {
          '1.1.1.1.in-addr.arpa' => '0.job-a.network-a.dep.bosh',
          '2.1.1.1.in-addr.arpa' => '1.job-a.network-a.dep.bosh',
          '1.2.1.1.in-addr.arpa' => '0.job-b.network-b.dep.bosh',
          '1.1.2.1.in-addr.arpa' => '0.job-a.network-a.dep-b.bosh'
        }.each do |key, value|
          Models::Dns::Record.make(:PTR, domain: domain, name: key, content: value)
        end

        dns_manager.delete_dns_for_instance(instance_model)

        expect(Models::Dns::Record.map(&:name)).to match_array(%w[
          1.job-a.network-a.dep.bosh
          0.job-b.network-b.dep.bosh
          0.job-a.network-a.dep-b.bosh
          2.1.1.1.in-addr.arpa
          1.2.1.1.in-addr.arpa
          1.1.2.1.in-addr.arpa
        ])
      end

      it 'allows to delete DNS domains in parallel threads' do
        Models::Dns::Record.make(
          domain: domain,
          name: '0.job-a.network-a.dep.bosh',
          content: '1.1.1.1',
        )

        rdomain = Models::Dns::Domain.make(name: '1.1.1.in-addr.arpa')
        Models::Dns::Record.make(domain: rdomain)
        Models::Dns::Record.make(domain: rdomain)

        expect_any_instance_of(Models::Dns::Domain).to receive(:require_modification=).with(false)
        dns_manager.delete_dns_for_instance(instance_model)
      end

      it 'deletes the reverse domain if it is empty' do
        rdomain = Models::Dns::Domain.make(name: '1.1.1.in-addr.arpa')
        Models::Dns::Record.make(domain: rdomain, type: 'SOA')
        Models::Dns::Record.make(domain: rdomain, type: 'NS')

        Models::Dns::Record.make(domain: domain, name: '0.job-a.network-a.dep.bosh', content: '1.1.1.1')
        Models::Dns::Record.make(:PTR, domain: rdomain, name: '1.1.1.1.in-addr.arpa', content: '0.job-a.network-a.dep.bosh')

        dns_manager.delete_dns_for_instance(instance_model)
        expect(Models::Dns::Record.all).to be_empty
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
        before { allow(Config).to receive(:dns).and_return({'server' => '9.10.11.12'}) }

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

        it 'should not add default dns server if it is 127.0.0.1' do
          allow(Config).to receive(:dns).and_return({'server' => '127.0.0.1'})
          expect(dns_manager.dns_servers('network', %w[1.2.3.4])).to eq(%w[1.2.3.4])
        end

        it 'should not add default dns server when dns is not enabled' do
          allow(Config).to receive(:dns_enabled?).and_return(false)
          expect(dns_manager.dns_servers('network', %w[1.2.3.4])).to eq(%w[1.2.3.4])
        end
      end
    end

    describe '#dns_domain_name' do
      it 'should return the DNS domain name' do
        allow(Config).to receive(:dns_domain_name).and_return('test_domain')
        expect(dns_manager.dns_domain_name).to eq('test_domain')
      end
    end

    describe '#dns_ns_record' do
      it 'should return the DNS name server' do
        allow(Config).to receive(:dns_domain_name).and_return('test_domain')
        expect(dns_manager.dns_ns_record).to eq('ns.test_domain')
      end
    end
  end
end
