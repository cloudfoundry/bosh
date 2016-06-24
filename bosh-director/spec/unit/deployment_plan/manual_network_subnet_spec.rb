require 'spec_helper'

describe 'Bosh::Director::DeploymentPlan::ManualNetworkSubnet' do
  before { @network = instance_double('Bosh::Director::DeploymentPlan::Network', :name => 'net_a') }

  def make_subnet(properties, availability_zones)
    BD::DeploymentPlan::ManualNetworkSubnet.parse(@network.name, properties, availability_zones, reserved_ranges)
  end

  let(:reserved_ranges) { {} }
  let(:instance) { instance_double(BD::DeploymentPlan::Instance, model: BD::Models::Instance.make) }

  def create_static_reservation(ip)
    BD::StaticNetworkReservation.new(instance, @network, NetAddr::CIDR.create(ip))
  end

  def create_dynamic_reservation(ip)
    reservation = BD::DynamicNetworkReservation.new(instance, @network)
    reservation.resolve_ip(NetAddr::CIDR.create(ip))
    reservation
  end

  describe :initialize do
    it 'should create a subnet spec' do
      subnet = make_subnet(
        {
          'range' => '192.168.0.0/24',
          'gateway' => '192.168.0.254',
          'cloud_properties' => {'foo' => 'bar'}
        },
        [],
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
          {
            'cloud_properties' => {'foo' => 'bar'},
            'gateway' => '192.168.0.254',
          },
          []
        )
      }.to raise_error(BD::ValidationMissingField)
    end

    context 'when generating log output' do
      before do
        allow(Bosh::Director::Config).to receive(:logger).and_return(logger)
      end
      let(:reserved_ranges) {
        Set.new [
                    NetAddr::CIDR.create('192.168.2.2/32'),
                    NetAddr::CIDR.create('192.168.0.0/24'),
                    NetAddr::CIDR.create('192.168.1.0/24')
                ]
      }
      it 'should log a reasonable debug message' do
        expect(logger).to receive(:debug).with('reserved ranges 192.168.2.2, 192.168.0.0-192.168.0.255, 192.168.1.0-192.168.1.255')
        subnet = make_subnet(
            {
                'range' => '192.168.0.0/24',
                'gateway' => '192.168.0.254',
                'reserved' => [
                    '192.168.0.10 - 192.168.0.20',
                    '192.168.0.30 - 192.168.0.50',
                    '192.168.0.100'
                ],
                'cloud_properties' => {'foo' => 'bar'}
            },
            [],
        )
      end
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
        }.to raise_error(BD::ValidationMissingField)
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

    it 'should allow a gateway' do
      subnet = make_subnet(
        {
          'range' => '192.168.0.0/24',
          'gateway' => '192.168.0.254',
          'cloud_properties' => {'foo' => 'bar'}
        },
        []
      )

      expect(subnet.gateway.ip).to eq('192.168.0.254')
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
      }.to raise_error(BD::NetworkInvalidGateway,
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
      }.to raise_error(BD::NetworkInvalidGateway,
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

    describe 'availability zone(s)' do
      context 'when the subnet defines both az and azs properties' do
        it 'errors' do
          expect {
            make_subnet(
              {
                'range' => '192.168.0.0/24',
                'gateway' => '192.168.0.254',
                'cloud_properties' => {},
                'az' => 'foo',
                'azs' => ['foo']
              },
              [
                Bosh::Director::DeploymentPlan::AvailabilityZone.new('foo', {}),
              ])
          }.to raise_error(Bosh::Director::NetworkInvalidProperty, "Network 'net_a' contains both 'az' and 'azs'. Choose one.")
        end

      end

      context 'when the subnet defines azs property' do
        describe 'when valid' do
          it 'should return the zones' do
            subnet = make_subnet(
              {
                'range' => '192.168.0.0/24',
                'gateway' => '192.168.0.254',
                'cloud_properties' => {},
                'azs' => ['foo', 'bar']
              },
              [
                Bosh::Director::DeploymentPlan::AvailabilityZone.new('foo', {}),
                Bosh::Director::DeploymentPlan::AvailabilityZone.new('bar', {})
              ]
            )
            expect(subnet.availability_zone_names).to eq(['foo', 'bar'])
          end
        end

        describe 'and the array is empty' do
          it 'errors' do
            expect {
              make_subnet(
                {
                  'range' => '192.168.0.0/24',
                  'gateway' => '192.168.0.254',
                  'cloud_properties' => {},
                  'azs' => []
                },
                [
                  Bosh::Director::DeploymentPlan::AvailabilityZone.new('foo', {}),
                ])
            }.to raise_error(Bosh::Director::NetworkInvalidProperty, "Network 'net_a' refers to an empty 'azs' array")
          end
        end

        describe 'and one of the zones dont exist' do
          it 'errors' do
            expect {
              make_subnet(
              {
                'range' => '192.168.0.0/24',
                'gateway' => '192.168.0.254',
                'cloud_properties' => {},
                'azs' => ['foo', 'bar']
              },
              [
                Bosh::Director::DeploymentPlan::AvailabilityZone.new('foo', {}),
              ])
            }.to raise_error(Bosh::Director::NetworkSubnetUnknownAvailabilityZone, "Network 'net_a' refers to an unknown availability zone 'bar'")
          end
        end
      end

      context 'when the subnet defines az property' do

        context 'with no availability zone specified' do
          it 'does not care whether that az name is in the list' do
            expect {
              make_subnet(
                {
                  'range' => '192.168.0.0/24',
                  'gateway' => '192.168.0.254',
                  'cloud_properties' => {'foo' => 'bar'},
                },
                []
              )
            }.to_not raise_error
          end
        end

        context 'with a nil availability zone' do
          it 'errors' do
            expect {
              make_subnet(
                {
                  'range' => '192.168.0.0/24',
                  'gateway' => '192.168.0.254',
                  'cloud_properties' => {'foo' => 'bar'},
                  'az' => nil
                },
                [Bosh::Director::DeploymentPlan::AvailabilityZone.new('foo', {})]
              )
            }.to raise_error(BD::ValidationInvalidType)
          end
        end

        context 'with an availability zone that is present' do
          def make_valid_subnet
            make_subnet(
              {
                'range' => '192.168.0.0/24',
                'gateway' => '192.168.0.254',
                'cloud_properties' => {'foo' => 'bar'},
                'az' => 'foo'
              },
              [
                Bosh::Director::DeploymentPlan::AvailabilityZone.new('bar', {}),
                Bosh::Director::DeploymentPlan::AvailabilityZone.new('foo', {})
              ]
            )
          end

          it 'is valid' do
            expect { make_valid_subnet }.to_not raise_error
          end

          it 'is returned by the subnet' do
            expect(make_valid_subnet.availability_zone_names).to eq(['foo'])
          end
        end

        context 'with an availability zone that is not present' do
          it 'errors' do
            expect {
              make_subnet(
                {
                  'range' => '192.168.0.0/24',
                  'gateway' => '192.168.0.254',
                  'cloud_properties' => {'foo' => 'bar'},
                  'az' => 'foo'
                },
                [
                  Bosh::Director::DeploymentPlan::AvailabilityZone.new('bar', {}),
                ]
              )}.to raise_error(Bosh::Director::NetworkSubnetUnknownAvailabilityZone, "Network 'net_a' refers to an unknown availability zone 'foo'")
          end
        end
      end

    end
  end

  describe :overlaps? do
    before(:each) do
      @subnet = make_subnet(
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
      expect(@subnet.overlaps?(other)).to eq(false)
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
      expect(@subnet.overlaps?(other)).to eq(true)
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
          expect(subnet.is_reservable?(NetAddr::CIDR.create('192.168.0.55'))).to be_falsey
        end
      end

      context 'when subnet reserved does not include IP' do
        it 'returns true' do
          expect(subnet.is_reservable?(NetAddr::CIDR.create('192.168.0.55'))).to be_truthy
        end
      end
    end

    context 'when subnet range does not include IP' do
      it 'returns false' do
        expect(subnet.is_reservable?(NetAddr::CIDR.create('192.168.10.55'))).to be_falsey
      end
    end
  end
end
