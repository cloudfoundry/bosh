require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe IpProvider do
    subject(:ip_provider) { IpProvider.new }

    describe 'next_available' do
      let(:range) { NetAddr::CIDR.create('192.168.0.1/24') }
      context 'when there are no IPs for that network' do
        it 'returns the first in the range' do
          ip_address = ip_provider.next_available('fake-network', range)

          expected_ip_address = NetAddr::CIDR.create('192.168.0.0')
          expect(ip_address.address).to eq(expected_ip_address)
          expect(ip_address.network_name).to eq('fake-network')
        end
      end

      context 'when there are available IPs between reserved IPs' do
        before do
          IpAddress.new(NetAddr::CIDR.create('192.168.0.0'), 'fake-network').reserve
          IpAddress.new(NetAddr::CIDR.create('192.168.0.1'), 'fake-network').reserve
          IpAddress.new(NetAddr::CIDR.create('192.168.0.3'), 'fake-network').reserve
        end

        it 'returns first non-reserved IP' do
          ip_address = ip_provider.next_available('fake-network', range)

          expected_ip_address = NetAddr::CIDR.create('192.168.0.2')
          expect(ip_address.address).to eq(expected_ip_address)
          expect(ip_address.network_name).to eq('fake-network')
        end
      end

      context 'when all IPs are reserved without holes' do
        before do
          IpAddress.new(NetAddr::CIDR.create('192.168.0.0'), 'fake-network').reserve
          IpAddress.new(NetAddr::CIDR.create('192.168.0.1'), 'fake-network').reserve
          IpAddress.new(NetAddr::CIDR.create('192.168.0.2'), 'fake-network').reserve
        end

        it 'returns IP next after reserved' do
          ip_address = ip_provider.next_available('fake-network', range)

          expected_ip_address = NetAddr::CIDR.create('192.168.0.3')
          expect(ip_address.address).to eq(expected_ip_address)
          expect(ip_address.network_name).to eq('fake-network')
        end
      end

      context 'when all IPs in the range are taken' do
        let(:range) { NetAddr::CIDR.create('192.168.0.1/32') }
        before do
          last_available_ip_address = NetAddr::CIDR.create('192.168.0.1')
          IpAddress.new(last_available_ip_address, 'fake-network').reserve
        end

        it 'returns nil' do
          ip_address = ip_provider.next_available('fake-network', range)
          expect(ip_address).to eq(nil)
        end
      end
    end
  end

  describe IpAddress do
    subject(:ip_address) { IpAddress.new(cidr_address, 'fake-network') }
    let(:cidr_address) { NetAddr::CIDR.create('192.168.0.1') }

    describe 'reserve' do
      it 'creates IP in database' do
        expect {
          ip_address.reserve
        }.to change(Bosh::Director::Models::IpAddress, :count).from(0).to(1)
        ip_address = Bosh::Director::Models::IpAddress.first
        expect(ip_address.address).to eq(cidr_address.to_i)
        expect(ip_address.network_name).to eq('fake-network')
      end
    end

    describe 'release' do
      context 'when IP exists in DB' do
        before do
          ip_address.reserve
        end

        it 'deletes the IP' do
          expect {
            ip_address.release
          }.to change(Bosh::Director::Models::IpAddress, :count).from(1).to(0)
        end
      end

      context 'when IP does not exist in DB' do
        it 'raises an error' do
          expect {
            ip_address.release
          }.to raise_error /Failed to release non-existing IP/
        end
      end
    end
  end
end
