require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe InMemoryIpProvider do
    let(:ip_provider) do
      InMemoryIpProvider.new(
        NetAddr::CIDR.create('192.168.0.0/24'),
        'fake-network',
        [cidr_ip('192.168.0.11')],
        [cidr_ip('192.168.0.5'), cidr_ip('192.168.0.10')],
      )
    end

    def cidr_ip(ip)
      NetAddr::CIDR.create(ip).to_i
    end

    describe :reserve_ip do
      it 'should reserve dynamic IPs' do
        expect(ip_provider.reserve_ip(cidr_ip('192.168.0.1'))).to eq(:dynamic)
      end

      it 'should reserve static IPs' do
        expect(ip_provider.reserve_ip(cidr_ip('192.168.0.5'))).to eq(:static)
      end

      it 'should fail to reserve restricted IPs' do
        expect(ip_provider.reserve_ip(cidr_ip('192.168.0.11'))).to eq(nil)
      end

      it 'should fail to reserve the IP if it was already reserved' do
        expect(ip_provider.reserve_ip(cidr_ip('192.168.0.5'))).to eq(:static)
        expect(ip_provider.reserve_ip(cidr_ip('192.168.0.5'))).to eq(nil)
      end
    end

    describe :allocate_dynamic_ip do
      it 'should allocate an IP from the dynamic pool' do
        ip = ip_provider.allocate_dynamic_ip
        expect(ip).to eq(cidr_ip('192.168.0.0'))
      end

      context 'when all IPs are restricted' do
        let(:ip_provider) do
          InMemoryIpProvider.new(
            NetAddr::CIDR.create('192.168.0.0/31'),
            'fake-network',
            [cidr_ip('192.168.0.0'), cidr_ip('192.168.0.1')],
            [],
          )
        end

        it 'should not allocate from the restricted pool' do
          expect(ip_provider.allocate_dynamic_ip).to eq(nil)
        end
      end

      context 'when all IPs are static' do
        let(:ip_provider) do
          InMemoryIpProvider.new(
            NetAddr::CIDR.create('192.168.0.0/31'),
            'fake-network',
            [],
            [cidr_ip('192.168.0.0'), cidr_ip('192.168.0.1')],
          )
        end

        it 'should not allocate from the static pool' do
          expect(ip_provider.allocate_dynamic_ip).to eq(nil)
        end
      end

      context 'when some IPs are static' do
        let(:ip_provider) do
          InMemoryIpProvider.new(
            NetAddr::CIDR.create('192.168.0.0/30'),
            'fake-network',
            [],
            [cidr_ip('192.168.0.2')],
          )
        end

        it 'should not allocate from the static pool' do
          expect(ip_provider.allocate_dynamic_ip).to eq(cidr_ip('192.168.0.0'))
          expect(ip_provider.allocate_dynamic_ip).to eq(cidr_ip('192.168.0.1'))
          expect(ip_provider.allocate_dynamic_ip).to eq(cidr_ip('192.168.0.3'))
          expect(ip_provider.allocate_dynamic_ip).to be_nil
        end
      end

      context 'there are no more IPs left to allocate' do
        let(:ip_provider) do
          InMemoryIpProvider.new(
            NetAddr::CIDR.create('192.168.0.0/29'),
            'fake-network',
            [],
            [],
          )
        end

        it 'should return nil' do
          8.times { expect(ip_provider.allocate_dynamic_ip).not_to eq(nil) }
          expect(ip_provider.allocate_dynamic_ip).to eq(nil)
        end
      end

      context 'when IPs released from dynamic pool' do
        let(:ip_provider) do
          InMemoryIpProvider.new(
            NetAddr::CIDR.create('192.168.0.0/29'),
            'fake-network',
            [],
            [],
          )
        end

        it 'should allocate the least recently released IP' do
          allocations = []
          while ip = ip_provider.allocate_dynamic_ip
            allocations << ip
          end

          # Release allocated IPs in random order
          allocations.shuffle!
          allocations.each do |ip|
            ip_provider.release_ip(ip)
          end

          # Verify that re-acquiring the released IPs retains order
          allocations.each do |ip|
            expect(ip_provider.allocate_dynamic_ip).to eq(ip)
          end
        end
      end

      describe :release_ip do
        let(:ip_provider) do
          InMemoryIpProvider.new(
            NetAddr::CIDR.create('192.168.0.0/24'),
            'fake-network',
            [cidr_ip('192.168.0.0')],
            [
              cidr_ip('192.168.0.5'), cidr_ip('192.168.0.6'),
              cidr_ip('192.168.0.7'), cidr_ip('192.168.0.8'),
              cidr_ip('192.168.0.9'), cidr_ip('192.168.0.10')
            ],
          )
        end

        it 'should release IPs' do
          ip_address = cidr_ip('192.168.0.1')
          expect(ip_provider.reserve_ip(ip_address)).to eq(:dynamic)
          expect(ip_provider.reserve_ip(ip_address)).to eq(nil)
          ip_provider.release_ip(ip_address)
          expect(ip_provider.reserve_ip(ip_address)).to eq(:dynamic)
        end

        it 'should fail if the IP is restricted' do
          message = "Can't release IP `192.168.0.0' back to `fake-network' network: " +
            "it's neither in dynamic nor in static pool"
          expect {
            ip_provider.release_ip(cidr_ip('192.168.0.0'))
          }.to raise_error(Bosh::Director::NetworkReservationIpNotOwned,
              message)
        end
      end
    end
  end
end
