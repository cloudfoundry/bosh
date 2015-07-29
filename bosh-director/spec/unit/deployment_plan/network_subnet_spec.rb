require 'spec_helper'

describe 'Bosh::Director::DeploymentPlan::NetworkSubnet' do
  before { @network = instance_double('Bosh::Director::DeploymentPlan::Network', :name => 'net_a') }
  let(:ip_provider_factory) { BD::DeploymentPlan::IpProviderFactory.new(logger, cloud_config: true) }

  def make_subnet(properties)
    BD::DeploymentPlan::NetworkSubnet.new(@network, properties, reserved_ranges, ip_provider_factory)
  end

  let(:reserved_ranges) { [] }
  let(:instance) { instance_double(BD::DeploymentPlan::Instance, model: BD::Models::Instance.make) }

  describe :initialize do
    it 'should create a subnet spec' do
      subnet = make_subnet(
        'range' => '192.168.0.0/24',
        'gateway' => '192.168.0.254',
        'cloud_properties' => {'foo' => 'bar'}
      )

      expect(subnet.range.ip).to eq('192.168.0.0')
      subnet.range.ip.size == 255
      expect(subnet.netmask).to eq('255.255.255.0')
      expect(subnet.gateway).to eq('192.168.0.254')
      expect(subnet.dns).to eq(nil)
    end

    it 'should require a range' do
      expect {
        make_subnet(
          'cloud_properties' => {'foo' => 'bar'},
          'gateway' => '192.168.0.254',
        )
      }.to raise_error(BD::ValidationMissingField)
    end

    it 'should require a gateway' do
      expect {
        make_subnet(
          'range' => '192.168.0.0/24',
          'cloud_properties' => {'foo' => 'bar'},
        )
      }.to raise_error(BD::ValidationMissingField)
    end

    it 'default cloud properties to empty hash' do
      subnet = make_subnet(
        'range' => '192.168.0.0/24',
        'gateway' => '192.168.0.254',
      )
      expect(subnet.cloud_properties).to eq({})
    end

    it 'should allow a gateway' do
      subnet = make_subnet(
        'range' => '192.168.0.0/24',
        'gateway' => '192.168.0.254',
        'cloud_properties' => {'foo' => 'bar'}
      )

      expect(subnet.gateway.ip).to eq('192.168.0.254')
    end

    it 'should make sure gateway is a single ip' do
      expect {
        make_subnet(
          'range' => '192.168.0.0/24',
          'gateway' => '192.168.0.254/30',
          'cloud_properties' => {'foo' => 'bar'}
        )
      }.to raise_error(BD::NetworkInvalidGateway,
          /must be a single IP/)
    end

    it 'should make sure gateway is inside the subnet' do
      expect {
        make_subnet(
          'range' => '192.168.0.0/24',
          'gateway' => '190.168.0.254',
          'cloud_properties' => {'foo' => 'bar'}
        )
      }.to raise_error(BD::NetworkInvalidGateway,
          /must be inside the range/)
    end

    it 'should make sure gateway is not the network id' do
      expect {
        make_subnet(
          'range' => '192.168.0.0/24',
          'gateway' => '192.168.0.0',
          'cloud_properties' => {'foo' => 'bar'}
        )
      }.to raise_error(Bosh::Director::NetworkInvalidGateway,
          /can't be the network id/)
    end

    it 'should make sure gateway is not the broadcast IP' do
      expect {
        make_subnet(
          'range' => '192.168.0.0/24',
          'gateway' => '192.168.0.255',
          'cloud_properties' => {'foo' => 'bar'}
        )
      }.to raise_error(Bosh::Director::NetworkInvalidGateway,
          /can't be the broadcast IP/)
    end

    it 'should allow DNS servers' do
      subnet = make_subnet(
        'range' => '192.168.0.0/24',
        'dns' => %w(1.2.3.4 5.6.7.8),
        'gateway' => '192.168.0.254',
        'cloud_properties' => {'foo' => 'bar'}
      )

      expect(subnet.dns).to eq(%w(1.2.3.4 5.6.7.8))
    end

    it 'should not allow reservation of reserved IPs' do
      subnet = make_subnet(
        'range' => '192.168.0.0/24', # 254 IPs
        'reserved' => '192.168.0.5 - 192.168.0.10', # 6 IPs
        'gateway' => '192.168.0.254', # 1 IP
      )

      expect(subnet.reserve_ip(instance, NetAddr::CIDR.create('192.168.0.4'))).to eq(:dynamic)
      expect(subnet.reserve_ip(instance, NetAddr::CIDR.create('192.168.0.5'))).to be_nil
      expect(subnet.reserve_ip(instance, NetAddr::CIDR.create('192.168.0.10'))).to be_nil
      expect(subnet.reserve_ip(instance, NetAddr::CIDR.create('192.168.0.11'))).to eq(:dynamic)
      expect(subnet.reserve_ip(instance, NetAddr::CIDR.create('192.168.0.253'))).to eq(:dynamic)
      expect(subnet.reserve_ip(instance, NetAddr::CIDR.create('192.168.0.254'))).to be_nil
    end

    context 'when there are reserved ranges' do
      let(:reserved_ranges) { [NetAddr::CIDR.create('192.168.0.0/28')] }

      it 'should not allow reservation of IPs from legacy reserved ranges' do
        subnet = make_subnet(
          'range' => '192.168.0.0/24',
          'gateway' => '192.168.0.254',
        )

        expect(subnet.reserve_ip(instance, NetAddr::CIDR.create('192.168.0.1'))).to be_nil
      end

      it 'should allocate dynamic IPs outside of those ranges' do
        subnet = make_subnet(
          'range' => '192.168.0.0/24',
          'gateway' => '192.168.0.254',
        )

        expect(subnet.allocate_dynamic_ip(instance)).to eq(NetAddr::CIDR.create('192.168.0.16').to_i)
      end

      it 'allows specifying static IPs that are in legacy reserved ranges' do
        subnet = make_subnet(
          'range' => '192.168.0.0/24',
          'gateway' => '192.168.0.254',
          'static' => ['192.168.0.1']
        )

        expect(subnet.reserve_ip(instance, NetAddr::CIDR.create('192.168.0.1'))).to eq(:static)
      end
    end

    it 'should fail when reserved range is not valid' do
      expect {
        make_subnet(
          'range' => '192.168.0.0/24',
          'reserved' => '192.167.0.5 - 192.168.0.10',
          'gateway' => '192.168.0.254',
          'cloud_properties' => {'foo' => 'bar'}
        )
      }.to raise_error(Bosh::Director::NetworkReservedIpOutOfRange,
          "Reserved IP `192.167.0.5' is out of " +
            "network `net_a' range")
    end

    it 'should allow reservation of static IPs' do
      subnet = make_subnet(
        'range' => '192.168.0.0/24', # 254 IPs
        'static' => '192.168.0.5 - 192.168.0.10', # 6 IPs
        'gateway' => '192.168.0.254', # 1 IP
        'cloud_properties' => {'foo' => 'bar'}
      )

      expect(subnet.reserve_ip(instance, NetAddr::CIDR.create('192.168.0.4'))).to eq(:dynamic)
      expect(subnet.reserve_ip(instance, NetAddr::CIDR.create('192.168.0.5'))).to eq(:static)
      expect(subnet.reserve_ip(instance, NetAddr::CIDR.create('192.168.0.10'))).to eq(:static)
      expect(subnet.reserve_ip(instance, NetAddr::CIDR.create('192.168.0.11'))).to eq(:dynamic)
      expect(subnet.reserve_ip(instance, NetAddr::CIDR.create('192.168.0.253'))).to eq(:dynamic)
      expect(subnet.reserve_ip(instance, NetAddr::CIDR.create('192.168.0.254'))).to be_nil
    end

    it 'should fail when the static IP is not valid' do
      expect {
        make_subnet(
          'range' => '192.168.0.0/24',
          'static' => '192.167.0.5 - 192.168.0.10',
          'gateway' => '192.168.0.254',
          'cloud_properties' => {'foo' => 'bar'}
        )
      }.to raise_error(Bosh::Director::NetworkStaticIpOutOfRange,
          "Static IP `192.167.0.5' is out of " +
            "network `net_a' range")
    end

    it 'should fail when the static IP is in reserved range' do
      expect {
        make_subnet(
          'range' => '192.168.0.0/24',
          'reserved' => '192.168.0.5 - 192.168.0.10',
          'static' => '192.168.0.5',
          'gateway' => '192.168.0.254',
          'cloud_properties' => {'foo' => 'bar'}
        )
      }.to raise_error(Bosh::Director::NetworkStaticIpOutOfRange,
          "Static IP `192.168.0.5' is out of " +
            "network `net_a' range")
    end
  end

  describe :overlaps? do
    before(:each) do
      @subnet = make_subnet(
        'range' => '192.168.0.0/24',
        'gateway' => '192.168.0.254',
        'cloud_properties' => {'foo' => 'bar'},
      )
    end

    it 'should return false when the given range does not overlap' do
      other = make_subnet(
        'range' => '192.168.1.0/24',
        'gateway' => '192.168.1.254',
        'cloud_properties' => {'foo' => 'bar'},
      )
      expect(@subnet.overlaps?(other)).to eq(false)
    end

    it 'should return true when the given range overlaps' do
      other = make_subnet(
        'range' => '192.168.0.128/28',
        'gateway' => '192.168.0.142',
        'cloud_properties' => {'foo' => 'bar'},
      )
      expect(@subnet.overlaps?(other)).to eq(true)
    end
  end
  
  describe 'validate!' do
    context 'with no availability zone specified' do
      it 'does not care whether that az name is in the list' do
        subnet = make_subnet(
          'range' => '192.168.0.0/24',
          'gateway' => '192.168.0.254',
          'cloud_properties' => {'foo' => 'bar'},
        )

        expect { subnet.validate!([]) }.to_not raise_error
      end
    end
    
    context 'with a nil availability zone' do
      it 'errors' do
        subnet = make_subnet(
          'range' => '192.168.0.0/24',
          'gateway' => '192.168.0.254',
          'cloud_properties' => {'foo' => 'bar'},
          'availability_zone' => nil
        )

        expect { subnet.validate!([instance_double(Bosh::Director::DeploymentPlan::AvailabilityZone)]) }.to_not raise_error
      end
    end
    
    context 'with an availability zone that is present' do
      it 'is valid' do
        subnet = make_subnet(
          'range' => '192.168.0.0/24',
          'gateway' => '192.168.0.254',
          'cloud_properties' => {'foo' => 'bar'},
          'availability_zone' => 'foo'
        )

        expect {
          subnet.validate!([
              instance_double(Bosh::Director::DeploymentPlan::AvailabilityZone, name: 'bar'),
              instance_double(Bosh::Director::DeploymentPlan::AvailabilityZone, name: 'foo'),
            ])
        }.to_not raise_error
      end
    end

    context 'with an availability zone that is not present' do
      it 'errors' do
        subnet = make_subnet(
          'range' => '192.168.0.0/24',
          'gateway' => '192.168.0.254',
          'cloud_properties' => {'foo' => 'bar'},
          'availability_zone' => 'foo'
        )

        expect {
          subnet.validate!([
              instance_double(Bosh::Director::DeploymentPlan::AvailabilityZone, name: 'bar'),
            ])
        }.to raise_error(Bosh::Director::NetworkSubnetUnknownAvailabilityZone, "Network 'net_a' refers to an unknown availability zone 'foo'")
      end
    end
  end
end
