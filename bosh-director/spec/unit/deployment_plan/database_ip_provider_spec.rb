require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe DatabaseIpProvider do
    subject(:ip_provider) do
      DatabaseIpProvider.new(
        range,
        'fake-network',
        restricted_ips,
        static_ips
      )
    end
    let(:restricted_ips) { Set.new }
    let(:static_ips) { Set.new }

    let(:range) { NetAddr::CIDR.create('192.168.0.1/24') }

    describe 'allocate_dynamic_ip' do
      context 'when there are no IPs for that network' do
        it 'returns the first in the range' do
          ip_address = ip_provider.allocate_dynamic_ip

          expected_ip_address = NetAddr::CIDR.create('192.168.0.0').to_i
          expect(ip_address).to eq(expected_ip_address)
        end
      end

      context 'when reserving more than one ip' do
        it 'should the next available address' do
          first = ip_provider.allocate_dynamic_ip
          second = ip_provider.allocate_dynamic_ip
          expect(first).to eq(NetAddr::CIDR.create('192.168.0.0').to_i)
          expect(second).to eq(NetAddr::CIDR.create('192.168.0.1').to_i)
        end
      end

      context 'when there are restricted ips' do
        let(:restricted_ips) do
          Set.new [
              NetAddr::CIDR.create('192.168.0.0').to_i,
              NetAddr::CIDR.create('192.168.0.1').to_i,
              NetAddr::CIDR.create('192.168.0.3').to_i
            ]
        end

        it 'does not reserve them' do
          expect(ip_provider.allocate_dynamic_ip).to eq(NetAddr::CIDR.create('192.168.0.2').to_i)
          expect(ip_provider.allocate_dynamic_ip).to eq(NetAddr::CIDR.create('192.168.0.4').to_i)
        end
      end

      context 'when there are static and restricted ips' do
        let(:restricted_ips) do
          Set.new [
              NetAddr::CIDR.create('192.168.0.0').to_i,
              NetAddr::CIDR.create('192.168.0.3').to_i
            ]
        end

        let(:static_ips) do
          Set.new [
              NetAddr::CIDR.create('192.168.0.1').to_i,
            ]
        end

        it 'does not reserve them' do
          expect(ip_provider.allocate_dynamic_ip).to eq(NetAddr::CIDR.create('192.168.0.2').to_i)
          expect(ip_provider.allocate_dynamic_ip).to eq(NetAddr::CIDR.create('192.168.0.4').to_i)
        end
      end

      context 'when there are available IPs between reserved IPs' do
        before do
          ip_provider.reserve_ip(NetAddr::CIDR.create('192.168.0.0'))
          ip_provider.reserve_ip(NetAddr::CIDR.create('192.168.0.1'))
          ip_provider.reserve_ip(NetAddr::CIDR.create('192.168.0.3'))
        end

        it 'returns first non-reserved IP' do
          ip_address = ip_provider.allocate_dynamic_ip

          expected_ip_address = NetAddr::CIDR.create('192.168.0.2').to_i
          expect(ip_address).to eq(expected_ip_address)
        end
      end

      context 'when all IPs are reserved without holes' do
        before do
          ip_provider.reserve_ip(NetAddr::CIDR.create('192.168.0.0'))
          ip_provider.reserve_ip(NetAddr::CIDR.create('192.168.0.1'))
          ip_provider.reserve_ip(NetAddr::CIDR.create('192.168.0.2'))
        end

        it 'returns IP next after reserved' do
          ip_address = ip_provider.allocate_dynamic_ip

          expected_ip_address = NetAddr::CIDR.create('192.168.0.3').to_i
          expect(ip_address).to eq(expected_ip_address)
        end
      end

      context 'when all IPs in the range are taken' do
        let(:range) { NetAddr::CIDR.create('192.168.0.0/32') }

        it 'returns nil' do
          expect(ip_provider.allocate_dynamic_ip).not_to be_nil
          expect(ip_provider.allocate_dynamic_ip).to be_nil
        end
      end
    end

    describe 'reserve_ip' do
      let(:ip_address) { NetAddr::CIDR.create('192.168.0.2') }

      it 'creates IP in database' do
        ip_provider
        expect {
          ip_provider.reserve_ip(ip_address)
        }.to change(Bosh::Director::Models::IpAddress, :count).by(1)
        saved_address = Bosh::Director::Models::IpAddress.order(:address).last
        expect(saved_address.address).to eq(ip_address.to_i)
        expect(saved_address.network_name).to eq('fake-network')
      end

      context 'when attempting to reserve a reserved ip' do
        it 'returns nil' do
          expect(ip_provider.reserve_ip(ip_address)).to eq(:dynamic)
          expect(ip_provider.reserve_ip(ip_address)).to be_nil
        end
      end

      context 'when reserving ip from restricted_ips list' do
        let(:restricted_ips) do
          Set.new [
              NetAddr::CIDR.create('192.168.0.2').to_i,
            ]
        end

        it 'returns nil' do
          expect(ip_provider.reserve_ip(ip_address)).to be_nil
        end
      end

      context 'when reserving static ip' do
        let(:static_ips) do
          Set.new [
              NetAddr::CIDR.create('192.168.0.2').to_i,
            ]
        end

        it 'returns static type' do
          expect(ip_provider.reserve_ip(ip_address)).to eq(:static)
        end
      end
    end

    describe 'release_ip' do
      let(:ip_address) { NetAddr::CIDR.create('192.168.0.3') }

      context 'when IP exists in DB' do
        before do
          ip_provider.reserve_ip(ip_address)
        end

        it 'deletes the IP' do
          expect {
            ip_provider.release_ip(ip_address)
          }.to change(Bosh::Director::Models::IpAddress, :count).by(-1)
        end
      end

      context 'when IP does not exist in DB' do
        it 'raises an error' do
          expect {
            ip_provider.release_ip(ip_address)
          }.to raise_error Bosh::Director::NetworkReservationIpNotOwned,
              "Can't release IP `192.168.0.3' back to `fake-network' network: it's neither in dynamic nor in static pool"
        end
      end
    end
  end
end
