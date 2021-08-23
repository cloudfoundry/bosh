require 'spec_helper'

module Bosh::Director
  module DeploymentPlan::NetworkParser
    describe NameServersParser do
      subject(:name_servers_parser) { NameServersParser.new() }

      it 'should return nil when there are no DNS servers' do
        expect(name_servers_parser.parse('network', {})).to be_nil
      end

      it 'should return an array of DNS servers' do
        expect(name_servers_parser.parse('network', {'dns' => %w[1.2.3.4 5.6.7.8]})).to eq(%w[1.2.3.4 5.6.7.8])
      end

      it "should raise an error if a DNS server isn't specified with as an IP" do
        expect {
          name_servers_parser.parse('network', {'dns' => %w[1.2.3.4 foo.bar]})
        }.to raise_error(NetAddr::ValidationError, /foo.bar is invalid \(contains invalid characters\)./)
      end

      context 'when power dns is not enabled' do
        let(:dns_config) do
          { 'server' => '9.10.11.12' }
        end

        before do
          allow(Config).to receive(:dns_db).and_return(false)
          allow(Config).to receive(:dns).and_return(dns_config)
        end

        it 'should not add the power dns nameserver' do
          expect(name_servers_parser.parse('network', {'dns' => %w[1.2.3.4]})).to eq(%w[1.2.3.4])
        end
      end

      context 'when power dns is enabled' do
        context 'when there is a default server' do
          let(:dns_config) do
            { 'server' => '9.10.11.12' }
          end

          before do
            allow(Config).to receive(:dns_db).and_return(true)
            allow(Config).to receive(:dns).and_return(dns_config)
          end

          it 'should add default dns server when there are no DNS servers' do
            expect(name_servers_parser.parse('network', {'dns' => []})).to eq(%w[9.10.11.12])
          end

          it 'should add default dns server to an array of DNS servers' do
            expect(name_servers_parser.parse('network', {'dns' => %w[1.2.3.4 5.6.7.8]})).to eq(%w[1.2.3.4 5.6.7.8 9.10.11.12])
          end

          it 'should not add default dns server if already set' do
            expect(name_servers_parser.parse('network', {'dns' => %w[1.2.3.4 9.10.11.12]})).to eq(%w[1.2.3.4 9.10.11.12])
          end

          context 'when dns server is 127.0.0.1' do
            let(:dns_config) do
              { 'server' => '127.0.0.1' }
            end

            it 'should not add default dns server if it is 127.0.0.1' do
              expect(name_servers_parser.parse('network', {'dns' => %w[1.2.3.4]})).to eq(%w[1.2.3.4])
            end
          end
        end
      end

    end
  end
end

