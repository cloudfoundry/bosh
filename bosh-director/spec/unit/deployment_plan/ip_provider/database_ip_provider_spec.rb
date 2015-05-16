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

    def cidr_ip(ip)
      NetAddr::CIDR.create(ip).to_i
    end

    describe 'allocate_dynamic_ip' do
      context 'when there are no IPs for that network' do
        it 'returns the first in the range' do
          ip_address = ip_provider.allocate_dynamic_ip

          expected_ip_address = cidr_ip('192.168.0.0')
          expect(ip_address).to eq(expected_ip_address)
        end
      end

      context 'when reserving more than one ip' do
        it 'should the next available address' do
          first = ip_provider.allocate_dynamic_ip
          second = ip_provider.allocate_dynamic_ip
          expect(first).to eq(cidr_ip('192.168.0.0'))
          expect(second).to eq(cidr_ip('192.168.0.1'))
        end
      end

      context 'when there are restricted ips' do
        let(:restricted_ips) do
          Set.new [
              cidr_ip('192.168.0.0'),
              cidr_ip('192.168.0.1'),
              cidr_ip('192.168.0.3')
            ]
        end

        it 'does not reserve them' do
          expect(ip_provider.allocate_dynamic_ip).to eq(cidr_ip('192.168.0.2'))
          expect(ip_provider.allocate_dynamic_ip).to eq(cidr_ip('192.168.0.4'))
        end
      end

      context 'when there are static and restricted ips' do
        let(:restricted_ips) do
          Set.new [
              cidr_ip('192.168.0.0'),
              cidr_ip('192.168.0.3')
            ]
        end

        let(:static_ips) do
          Set.new [
              cidr_ip('192.168.0.1'),
            ]
        end

        it 'does not reserve them' do
          expect(ip_provider.allocate_dynamic_ip).to eq(cidr_ip('192.168.0.2'))
          expect(ip_provider.allocate_dynamic_ip).to eq(cidr_ip('192.168.0.4'))
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

          expected_ip_address = cidr_ip('192.168.0.2')
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

          expected_ip_address = cidr_ip('192.168.0.3')
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

      context 'when restricted IPs has improper format' do
        let(:restricted_ips) do
          Set.new [
              '; bad idea;',
            ]
        end

        it 'properly escapes them' do
          expect {
            expect(ip_provider.allocate_dynamic_ip).to eq(nil)
          }.to_not raise_error
        end
      end
    end

    describe 'reserve_ip' do
      let(:ip_address) { cidr_ip('192.168.0.2') }

      it 'creates IP in database' do
        ip_provider
        expect {
          ip_provider.reserve_ip(ip_address)
        }.to change(Bosh::Director::Models::IpAddress, :count).by(1)
        saved_address = Bosh::Director::Models::IpAddress.order(:address).last
        expect(saved_address.address).to eq(ip_address.to_i)
        expect(saved_address.network_name).to eq('fake-network')
      end

      context 'when reserving dynamic IP' do
        it 'returns dynamic type' do
          expect(ip_provider.reserve_ip(ip_address)).to eq(:dynamic)
        end
      end

      context 'when reserving static ip' do
        let(:static_ips) do
          Set.new [
              cidr_ip('192.168.0.2'),
            ]
        end

        it 'returns static type' do
          expect(ip_provider.reserve_ip(ip_address)).to eq(:static)
        end
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
              cidr_ip('192.168.0.2'),
            ]
        end

        it 'returns nil' do
          expect(ip_provider.reserve_ip(ip_address)).to be_nil
        end
      end
    end

    describe 'release_ip' do
      let(:ip_address) { NetAddr::CIDR.create('192.168.0.3') }

      context 'when IP was reserved' do
        it 'releases the IP' do
          expect(ip_provider.reserve_ip(ip_address)).to eq(:dynamic)
          expect(ip_provider.reserve_ip(ip_address)).to eq(nil)
          ip_provider.release_ip(ip_address)
          expect(ip_provider.reserve_ip(ip_address)).to eq(:dynamic)
        end
      end

      context 'when IP is restricted' do
        let(:restricted_ips) do
          Set.new [
              cidr_ip('192.168.0.3'),
            ]
        end

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
