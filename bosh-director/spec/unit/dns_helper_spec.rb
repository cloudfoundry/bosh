require 'spec_helper'

module Bosh::Director
  describe DnsHelper do
    include Bosh::Director::ValidationHelper
    include Bosh::Director::DnsHelper

    describe '#canonical' do
      it 'should be lowercase' do
        expect(canonical('HelloWorld')).to eq('helloworld')
      end

      it 'should convert underscores to hyphens' do
        expect(canonical('hello_world')).to eq('hello-world')
      end

      it 'should strip any non alpha numeric characters' do
        expect(canonical('hello^world')).to eq('helloworld')
      end

      it "should reject strings that don't start with a letter or end with a letter/number" do
        expect {
          canonical('-helloworld')
        }.to raise_error(
          DnsInvalidCanonicalName,
          "Invalid DNS canonical name `-helloworld', must begin with a letter",
        )

        expect {
          canonical('helloworld-')
        }.to raise_error(
          DnsInvalidCanonicalName,
          "Invalid DNS canonical name `helloworld-', can't end with a hyphen",
        )
      end
    end

    describe '#dns_servers' do
      it 'should return nil when there are no DNS servers' do
        expect(dns_servers('network', {})).to be_nil
      end

      it 'should return an array of DNS servers' do
        expect(dns_servers('network', {'dns' => %w[1.2.3.4 5.6.7.8]})).to eq(%w[1.2.3.4 5.6.7.8])
      end

      it 'should add default dns server to an array of DNS servers' do
        allow(Config).to receive(:dns).and_return({'server' => '9.10.11.12'})
        expect(dns_servers('network', {'dns' => %w[1.2.3.4 5.6.7.8]})).to eq(%w[1.2.3.4 5.6.7.8 9.10.11.12])
      end

      it 'should not add default dns server to an array of DNS servers' do
        allow(Config).to receive(:dns).and_return({'server' => '9.10.11.12'})
        expect(dns_servers('network', {'dns' => %w[1.2.3.4 5.6.7.8]}, false)).to eq(%w[1.2.3.4 5.6.7.8])
      end

      it "should raise an error if a DNS server isn't specified with as an IP" do
        expect {
          dns_servers('network', {'dns' => %w[1.2.3.4 foo.bar]})
        }.to raise_error
      end
    end

    describe '#default_dns_server' do
      it 'should return nil when there are no default DNS server' do
        expect(default_dns_server).to be_nil
      end

      it 'should return the default DNS server when is set' do
        allow(Config).to receive(:dns).and_return({'server' => '1.2.3.4'})
        expect(default_dns_server).to eq('1.2.3.4')
      end
    end

    describe '#add_default_dns_server' do
      before { allow(Config).to receive(:dns).and_return({'server' => '9.10.11.12'}) }

      it 'should add default dns server when there are no DNS servers' do
        expect(add_default_dns_server([])).to eq(%w[9.10.11.12])
      end

      it 'should add default dns server to an array of DNS servers' do
        expect(add_default_dns_server(%w[1.2.3.4 5.6.7.8])).to eq(%w[1.2.3.4 5.6.7.8 9.10.11.12])
      end

      it 'should not add default dns server if already set' do
        expect(add_default_dns_server(%w[1.2.3.4 9.10.11.12])).to eq(%w[1.2.3.4 9.10.11.12])
      end

      it 'should not add default dns server if it is 127.0.0.1' do
        allow(Config).to receive(:dns).and_return({'server' => '127.0.0.1'})
        expect(add_default_dns_server(%w[1.2.3.4])).to eq(%w[1.2.3.4])
      end

      it 'should not add default dns server when dns is not enabled' do
        allow(Config).to receive(:dns_enabled?).and_return(false)
        expect(add_default_dns_server(%w[1.2.3.4])).to eq(%w[1.2.3.4])
      end
    end

    describe '#dns_domain_name' do
      it 'should return the DNS domain name' do
        allow(Config).to receive(:dns_domain_name).and_return('test_domain')
        expect(dns_domain_name).to eq('test_domain')
      end
    end

    describe '#dns_ns_record' do
      it 'should return the DNS name server' do
        allow(Config).to receive(:dns_domain_name).and_return('test_domain')
        expect(dns_ns_record).to eq('ns.test_domain')
      end
    end

    describe '#update_dns_a_record' do
      it 'should create new record' do
        domain = Models::Dns::Domain.make
        update_dns_a_record(domain, '0.foo.default.bosh', '1.2.3.4')
        record = Models::Dns::Record.find(domain_id: domain.id, name: '0.foo.default.bosh')
        expect(record.content).to eq('1.2.3.4')
        expect(record.type).to eq('A')
      end

      it 'should update existing record' do
        domain = Models::Dns::Domain.make
        update_dns_a_record(domain, '0.foo.default.bosh', '1.2.3.4')
        update_dns_a_record(domain, '0.foo.default.bosh', '5.6.7.8')
        record = Models::Dns::Record.find(domain_id: domain.id, name: '0.foo.default.bosh')
        expect(record.content).to eq('5.6.7.8')
      end
    end

    describe '#update_dns_ptr_record' do
      before { @logger = logger }

      it 'should create new record' do
        update_dns_ptr_record('0.foo.default.bosh', '1.2.3.4')
        record = Models::Dns::Record.find(name: '4.3.2.1.in-addr.arpa')
        expect(record.content).to eq('0.foo.default.bosh')
        expect(record.type).to eq('PTR')
        expect(Models::Dns::Domain.all.size).to eq(1)
        expect(Models::Dns::Record.all.size).to eq(3)
      end

      it 'should update existing record on a different subnet' do
        update_dns_ptr_record('0.foo.default.bosh', '1.2.3.4')
        update_dns_ptr_record('0.foo.default.bosh', '5.6.7.8')
        old_record = Models::Dns::Record.find(name: '4.3.2.1.in-addr.arpa')
        expect(old_record).to be_nil
        new_record = Models::Dns::Record.find(name: '8.7.6.5.in-addr.arpa')
        expect(new_record.content).to eq('0.foo.default.bosh')
        expect(Models::Dns::Domain.all.size).to eq(1)
        expect(Models::Dns::Record.all.size).to eq(3)
      end

      it 'should update existing record on the same subnet' do
        update_dns_ptr_record('0.foo.default.bosh', '1.2.3.4')
        update_dns_ptr_record('0.foo.default.bosh', '1.2.3.5')
        old_record = Models::Dns::Record.find(name: '4.3.2.1.in-addr.arpa')
        expect(old_record).to be_nil
        new_record = Models::Dns::Record.find(name: '5.3.2.1.in-addr.arpa')
        expect(new_record.content).to eq('0.foo.default.bosh')
        expect(Models::Dns::Domain.all.size).to eq(1)
        expect(Models::Dns::Record.all.size).to eq(3)
      end
    end

    describe '#delete_dns_records' do
      before { @logger = logger }

      it 'only deletes records that match the deployment, job, and index' do
        domain = Models::Dns::Domain.make

        {
          '0.job-a.network-a.dep.bosh' => '1.1.1.1',
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

        delete_dns_records('0.job-a.%.dep.bosh', domain.id)

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
        domain = Models::Dns::Domain.make
        Models::Dns::Record.make(
          domain: domain,
          name: '0.job-a.network-a.dep.bosh',
          content: '1.1.1.1',
        )

        rdomain = Models::Dns::Domain.make(name: '1.1.1.in-addr.arpa')
        Models::Dns::Record.make(domain: rdomain)
        Models::Dns::Record.make(domain: rdomain)

        expect_any_instance_of(Models::Dns::Domain).to receive(:require_modification=).with(false)
        delete_dns_records('0.job-a.%.dep.bosh', domain.id)
      end

      it 'deletes the reverse domain if it is empty' do
        domain = Models::Dns::Domain.make
        rdomain = Models::Dns::Domain.make(name: '1.1.1.in-addr.arpa')
        Models::Dns::Record.make(domain: rdomain, type: 'SOA')
        Models::Dns::Record.make(domain: rdomain, type: 'NS')

        Models::Dns::Record.make(domain: domain, name: '0.job-a.network-a.dep.bosh', content: '1.1.1.1')
        Models::Dns::Record.make(:PTR, domain: rdomain, name: '1.1.1.1.in-addr.arpa', content: '0.job-a.network-a.dep.bosh')

        delete_dns_records('0.job-a.%.dep.bosh', domain.id)
        expect(Models::Dns::Record.all).to be_empty
      end
    end

    describe '#flush_dns_cache' do
      before { @logger = double(:logger) }
      before { allow(Config).to receive(:dns).and_return({'flush_command' => flush_command}) }

      context 'when flush command is present' do
        let(:flush_command) { "echo \"7\" && exit 0" }

        it 'logs success' do
          expect(@logger).to receive(:debug).with("Flushed 7 records from DNS cache")
          flush_dns_cache
        end
      end

      context 'when running flush command fails' do
        let(:flush_command) { "echo fake failure >&2 && exit 1" }

        it 'logs an error' do
          expect(@logger).to receive(:warn).with("Failed to flush DNS cache: fake failure")
          flush_dns_cache
        end
      end

      context 'when flush command is not present' do
        let(:flush_command) { nil }

        it 'does not do anything' do
          expect(Open3).to_not receive(:capture3)
          expect {
            flush_dns_cache
          }.to_not raise_error
        end
      end
    end
  end
end
