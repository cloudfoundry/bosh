require 'spec_helper'

module Bosh::Director
  module DeploymentPlan::NetworkParser
    describe NameServersParser do
      subject(:name_servers_parser) { NameServersParser.new }

      it 'should return nil when there are no DNS servers' do
        expect(name_servers_parser.parse('network', {})).to be_nil
      end

      it 'should return an array of DNS servers' do
        expect(name_servers_parser.parse('network', {'dns' => %w[1.2.3.4 5.6.7.8]})).to eq(%w[1.2.3.4 5.6.7.8])
      end

      it "should raise an error if a DNS server isn't specified with as an IP" do
        expect {
          name_servers_parser.parse('network', {'dns' => %w[1.2.3.4 foo.bar]})
        }.to raise_error(/Invalid IP or CIDR format/)
      end

      it 'returns an array containing the nameserver address' do
        expect(name_servers_parser.parse('network', {'dns' => %w[1.2.3.4]})).to eq(%w[1.2.3.4])
      end
    end
  end
end

