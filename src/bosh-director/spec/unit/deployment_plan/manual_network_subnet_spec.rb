require 'spec_helper'
require 'ipaddr'

describe Bosh::Director::DeploymentPlan::ManualNetworkSubnet do
  before { @network = instance_double('Bosh::Director::DeploymentPlan::Network', name: 'net_a') }

  def make_subnet(properties, availability_zones)
    Bosh::Director::DeploymentPlan::ManualNetworkSubnet.parse(@network.name, properties, availability_zones)
  end

  def make_managed_subnet(properties, availability_zones)
    Bosh::Director::DeploymentPlan::ManualNetworkSubnet.parse(@network.name, properties, availability_zones, true)
  end

  it_behaves_like 'a subnet'

  describe '#initialize' do
    it 'should create a subnet spec' do
      subnet = make_subnet(
        {
          'range' => '192.168.0.0/24',
          'gateway' => '192.168.0.254',
          'cloud_properties' => {'foo' => 'bar'}
        },
        [],
      )

      expect(subnet.range.to_cidr_s).to eq('192.168.0.0/24')
      expect(subnet.netmask).to eq('255.255.255.0')
      expect(subnet.gateway).to eq('192.168.0.254')
      expect(subnet.dns).to eq(nil)
    end

    it 'should create valid subnet spec for managed networks' do
      subnet = make_managed_subnet(
        {
          'name' => 'some-subnet',
          'range' => '192.168.0.0/24',
          'gateway' => '192.168.0.254',
          'cloud_properties' => { 'foo' => 'bar' },
        },
        [],
      )

      expect(subnet.range.to_cidr_s).to eq('192.168.0.0/24')
      expect(subnet.netmask).to eq('255.255.255.0')
      expect(subnet.gateway).to eq('192.168.0.254')
      expect(subnet.dns).to eq(nil)
    end

    it 'should fail when managed subnet has no name' do
      expect do
        make_managed_subnet(
          {
            'netmask_bits' => 24,
            'cloud_properties' => { 'foo' => 'bar' },
          },
          [],
        )
      end.to raise_error(Bosh::Director::ValidationMissingField)
    end

    it 'should create a valid managed subnet with netmask bits' do
      subnet = make_managed_subnet({
        'name' => 'subnet-name',
        'netmask_bits' => 24,
        'cloud_properties' => { 'foo' => 'bar' },
      }, [])
      expect(subnet.netmask_bits).to eq(24)
    end

    it 'should create an IPv6 subnet spec' do
      subnet = make_subnet(
        {
          'range' => 'fdab:d85c:118d:8a46::/64',
          'gateway' => 'fdab:d85c:118d:8a46::1',
          'reserved' => [
            'fdab:d85c:118d:8a46::10-fdab:d85c:118d:8a46::ff',
            'fdab:d85c:118d:8a46::101',
          ],
          'static' => [
            'fdab:d85c:118d:8a46::210-fdab:d85c:118d:8a46::2ff',
            'fdab:d85c:118d:8a46::301',
          ],
          'dns' => [
            '2001:4860:4860::8888',
            '2001:4860:4860::8844',
          ],
          'cloud_properties' => {'foo' => 'bar'}
        },
        [],
      )

      expect(subnet.range).to eq('fdab:d85c:118d:8a46:0000:0000:0000:0000')
      expect(subnet.netmask).to eq('ffff:ffff:ffff:ffff:0000:0000:0000:0000')
      expect(subnet.gateway).to eq('fdab:d85c:118d:8a46:0000:0000:0000:0001')
      expect(subnet.dns).to eq([
        "2001:4860:4860:0000:0000:0000:0000:8888",
        "2001:4860:4860:0000:0000:0000:0000:8844",
      ])
    end

    it 'should require a range' do
      expect {
        make_subnet(
          {
            'cloud_properties' => {'foo' => 'bar'},
            'gateway' => '192.168.0.254',
          },
          []
        )
      }.to raise_error(Bosh::Director::ValidationMissingField)
    end

    context 'gateway property' do
      it 'should require a gateway' do
        expect {
          make_subnet(
            {
              'range' => '192.168.0.0/24',
              'cloud_properties' => {'foo' => 'bar'},
            }, []
          )
        }.to raise_error(Bosh::Director::ValidationMissingField)
      end

      context 'when the gateway is configured to be optional' do
        it 'should not require a gateway' do
          allow(Bosh::Director::Config).to receive(:ignore_missing_gateway).and_return(true)

          expect {
            make_subnet(
              {
                'range' => '192.168.0.0/24',
                'cloud_properties' => {'foo' => 'bar'},
              },
              []
            )
          }.to_not raise_error
        end
      end
    end

    it 'default cloud properties to empty hash' do
      subnet = make_subnet(
        {

          'range' => '192.168.0.0/24',
          'gateway' => '192.168.0.254',
        },
        []
      )
      expect(subnet.cloud_properties).to eq({})
    end

    it 'should fail when cloud properties is NOT a hash' do
      expect {
        make_subnet(
            {
                'range' => '192.168.0.0/24',
                'gateway' => '192.168.0.254',
                'cloud_properties' => 'not_hash'
            },
            []
        )
      }.to raise_error(Bosh::Director::ValidationInvalidType)
    end

    it 'should allow a gateway' do
      subnet = make_subnet(
        {
          'range' => '192.168.0.0/24',
          'gateway' => '192.168.0.254',
          'cloud_properties' => {'foo' => 'bar'}
        },
        []
      )

      expect(subnet.gateway.to_s).to eq('192.168.0.254')
    end

    it 'should make sure gateway is a single ip' do
      expect {
        make_subnet(
          {
            'range' => '192.168.0.0/24',
            'gateway' => '192.168.0.254/30',
            'cloud_properties' => {'foo' => 'bar'}
          },
          []
        )
      }.to raise_error(Bosh::Director::NetworkInvalidGateway,
          /must be a single IP/)
    end

    it 'should make sure gateway is inside the subnet' do
      expect {
        make_subnet(
          {
            'range' => '192.168.0.0/24',
            'gateway' => '190.168.0.254',
            'cloud_properties' => {'foo' => 'bar'}
          },
          []
        )
      }.to raise_error(Bosh::Director::NetworkInvalidGateway,
          /must be inside the range/)
    end

    it 'should make sure gateway is not the network id' do
      expect {
        make_subnet(
          {
            'range' => '192.168.0.0/24',
            'gateway' => '192.168.0.0',
            'cloud_properties' => {'foo' => 'bar'}
          },
          []
        )
      }.to raise_error(Bosh::Director::NetworkInvalidGateway,
          /can't be the network id/)
    end

    it 'should make sure gateway is not the broadcast IP' do
      expect {
        make_subnet(
          {
            'range' => '192.168.0.0/24',
            'gateway' => '192.168.0.255',
            'cloud_properties' => {'foo' => 'bar'}
          },
          []
        )
      }.to raise_error(Bosh::Director::NetworkInvalidGateway,
          /can't be the broadcast IP/)
    end

    it 'should allow DNS servers' do
      subnet = make_subnet(
        {
          'range' => '192.168.0.0/24',
          'dns' => %w(1.2.3.4 5.6.7.8),
          'gateway' => '192.168.0.254',
          'cloud_properties' => {'foo' => 'bar'}
        },
        []
      )

      expect(subnet.dns).to eq(%w(1.2.3.4 5.6.7.8))
    end

    it 'should fail when reserved range is not valid' do
      expect {
        make_subnet(
          {
            'range' => '192.168.0.0/24',
            'reserved' => '192.167.0.5 - 192.168.0.10',
            'gateway' => '192.168.0.254',
            'cloud_properties' => {'foo' => 'bar'}
          },
          []
        )
      }.to raise_error(Bosh::Director::NetworkReservedIpOutOfRange,
          "Reserved IP '192.167.0.5' is out of " +
            "network 'net_a' range")
    end

    it 'should allow the reserved range to include the gateway, broadcast and network addresses' do
      expect {
        make_subnet(
          {
            'range' => '192.168.0.0/24',
            'reserved' => ['192.168.0.0','192.168.0.1','192.168.0.255'],
            'gateway' => '192.168.0.1',
            'cloud_properties' => {'foo' => 'bar'}
          },
          []
        )
      }.to_not raise_error
    end

    it 'should fail when the static IP is not valid' do
      expect {
        make_subnet(
          {
            'range' => '192.168.0.0/24',
            'static' => '192.167.0.5 - 192.168.0.10',
            'gateway' => '192.168.0.254',
            'cloud_properties' => {'foo' => 'bar'}
          },
          []
        )
      }.to raise_error(Bosh::Director::NetworkStaticIpOutOfRange,
          "Static IP '192.167.0.5' is out of " +
            "network 'net_a' range")
    end

    it 'should fail when the static IP is in reserved range' do
      expect {
        make_subnet(
          {
            'range' => '192.168.0.0/24',
            'reserved' => '192.168.0.5 - 192.168.0.10',
            'static' => '192.168.0.5',
            'gateway' => '192.168.0.254',
            'cloud_properties' => {'foo' => 'bar'}
          },
          []
        )
      }.to raise_error(Bosh::Director::NetworkStaticIpOutOfRange,
          "Static IP '192.168.0.5' is in network 'net_a' reserved range")
    end

    it 'should include the directors ip addresses in the reserved range' do
      ip1 = IPAddr.new('192.168.1.1')
      ip2 = IPAddr.new('192.168.1.2')

      allow(Bosh::Director::Config).to receive(:director_ips).and_return([ip1.to_s, ip2.to_s])
      subnet = make_subnet(
        {
          'range' => '192.168.0.0/24',
          'reserved' => ['192.168.0.0', '192.168.0.1', '192.168.0.255'],
          'gateway' => '192.168.0.1',
          'cloud_properties' => { 'foo' => 'bar' },
        },
        [],
      )

      expect(subnet.restricted_ips).to include(ip1.to_i)
      expect(subnet.restricted_ips).to include(ip2.to_i)
    end
  end

  describe :overlaps? do
    let(:subnet) do
      make_subnet(
        {
          'range' => '192.168.0.0/24',
          'gateway' => '192.168.0.254',
          'cloud_properties' => {'foo' => 'bar'},
        },
        []
      )
    end

    it 'should return false when the given range does not overlap' do
      other = make_subnet(
        {
          'range' => '192.168.1.0/24',
          'gateway' => '192.168.1.254',
          'cloud_properties' => {'foo' => 'bar'},
        },
        []
      )
      expect(subnet.overlaps?(other)).to eq(false)
    end

    it 'should return true when the given range overlaps' do
      other = make_subnet(
        {
          'range' => '192.168.0.128/28',
          'gateway' => '192.168.0.142',
          'cloud_properties' => {'foo' => 'bar'},
        },
        []
      )
      expect(subnet.overlaps?(other)).to eq(true)
    end

    it 'should return false when IPv4 and IPv6 ranges are compared' do
      other = make_subnet(
        {
          'range' => 'f1ee:0000:0000:0000:0000:0000:0000:0000/64',
          'gateway' => 'f1ee:0000:0000:0000:0000:0000:0000:0001',
          'cloud_properties' => { 'foo' => 'bar' },
        },
        [],
      )
      expect(subnet.overlaps?(other)).to eq(false)
    end
  end

  describe :is_reservable? do
    let(:subnet) do
      make_subnet(
        {
          'range' => '192.168.0.1/24',
          'gateway' => '192.168.0.254',
          'reserved' => reserved
        },
        []
      )
    end
    let(:reserved) { [] }

    context 'when subnet range includes IP' do
      context 'when subnet reserved includes IP' do
        let(:reserved) { ['192.168.0.50-192.168.0.60'] }

        it 'returns false' do
          expect(subnet.is_reservable?(IPAddr.new('192.168.0.55'))).to be_falsey
        end
      end

      context 'when subnet reserved does not include IP' do
        it 'returns true' do
          expect(subnet.is_reservable?(IPAddr.new('192.168.0.55'))).to be_truthy
        end
      end
    end

    context 'when subnet range does not include IP' do
      it 'returns false' do
        expect(subnet.is_reservable?(IPAddr.new('192.168.10.55'))).to be_falsey
      end
    end

    context 'when subnet range is not the same IP version' do
      it 'returns false' do
        expect(subnet.is_reservable?(IPAddr.new('f1ee:0000:0000:0000:0000:0000:0000:0001'))).to be_falsey
      end
    end
  end
end
