require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe InMemoryIpRepo do
    let(:restricted_ips) { [] }
    let(:static_ips) { [] }
    let(:ip_repo) { InMemoryIpRepo.new(logger) }

    let(:ip_address) { NetAddr::CIDR.create('192.168.1.5') }
    let(:subnet) { ManualNetworkSubnet.new(network, network_spec['subnets'].first, availability_zones, [], ip_provider_factory) }
    let(:network) do
      BD::DeploymentPlan::ManualNetwork.new(
        network_spec,
        availability_zones,
        global_network_resolver,
        ip_provider_factory,
        logger
      )
    end
    let(:availability_zones) do
      [
        BD::DeploymentPlan::AvailabilityZone.new('zone_1', {}),
        BD::DeploymentPlan::AvailabilityZone.new('zone_2', {})
      ]
    end

    let(:network_spec) {
      {
        'name' => 'my-network',
        'subnets' => [
          {
            'range' => '192.168.1.0/24',
            'gateway' => '192.168.1.1',
            'dns' => ['192.168.1.1', '192.168.1.2'],
            'static' => [],
            'reserved' => [],
            'cloud_properties' => {},
            'availability_zone' => 'zone_1',
          }
        ]
      }
    }
    let(:global_network_resolver) { instance_double(BD::DeploymentPlan::GlobalNetworkResolver, reserved_legacy_ranges: []) }
    let(:ip_provider_factory) { BD::DeploymentPlan::IpProviderFactory.new(logger, {}) }
    let(:network_name) { network_spec['name'] }
    let(:instance) { instance_double(BD::DeploymentPlan::Instance, availability_zone: nil) }

    describe :add do
      context 'when IP was already added in that subnet' do
        before do
          ip_repo.add(ip_address, subnet)
        end

        it 'raises an error' do
          message = "Failed to reserve IP '192.168.1.5' for '#{network_name}': already reserved"
          expect {
            ip_repo.add(ip_address, subnet)
          }.to raise_error(BD::NetworkReservationAlreadyInUse, message)
        end
      end

      context 'when IP is outside of subnet range' do
        let(:ip_address) { NetAddr::CIDR.create('192.168.5.5') }
        it 'raises an error' do
          message = "Can't reserve IP '192.168.5.5' to '#{network_name}' network: " +
            "it's neither in dynamic nor in static pool"
          expect {
            ip_repo.add(ip_address, subnet)
          }.to raise_error(Bosh::Director::NetworkReservationIpNotOwned,
              message)
        end
      end

      context 'when IP is valid' do
        it 'adds the IP' do
          ip_repo.add(ip_address, subnet)

          expect {
            ip_repo.add(ip_address, subnet)
          }.to raise_error BD::NetworkReservationAlreadyInUse
        end
      end

      context 'when IP is in reserved range' do
        before do
          network_spec['subnets'].first['reserved'] = ['192.168.1.5']
        end
        let(:restricted_ips) { [ip_address] }

        it 'raises Bosh::Director::NetworkReservationIpReserved' do
          message = "Failed to reserve IP '192.168.1.5' for network '#{network_name}': IP belongs to reserved range"
          expect {
            ip_repo.add(ip_address, subnet)
          }.to raise_error(Bosh::Director::NetworkReservationIpReserved, message)
        end
      end
    end

    describe :delete do
      it 'should delete IPs' do
        ip_repo.add(ip_address, subnet)

        expect {
          ip_repo.add(ip_address, subnet)
        }.to raise_error BD::NetworkReservationAlreadyInUse

        ip_repo.delete(ip_address, subnet.network.name)

        expect {
          ip_repo.add(ip_address, subnet)
        }.to_not raise_error
      end
    end

    context 'when IP is a Fixnum' do
      let(:ip_address_to_i) { NetAddr::CIDR.create('192.168.1.3').to_i }
      it 'adds and deletes IPs' do
        ip_repo.add(ip_address_to_i, subnet)

        expect {
          ip_repo.add(ip_address_to_i, subnet)
        }.to raise_error BD::NetworkReservationAlreadyInUse

        ip_repo.delete(ip_address_to_i, subnet.network.name)

        expect {
          ip_repo.add(ip_address_to_i, subnet)
        }.to_not raise_error
      end
    end

    context 'when IPs released from dynamic pool' do
      let(:network_spec) {
        {
          'name' => 'my-network',
          'subnets' => [
            {
              'range' => '192.168.1.0/29',
              'gateway' => '192.168.1.1',
              'dns' => ['192.168.1.1', '192.168.1.2'],
              'static' => [],
              'reserved' => ['192.168.1.2', '192.168.1.3', '192.168.1.4'],
              'cloud_properties' => {},
              'availability_zone' => 'zone_1',
            },
            {
              'range' => '192.168.2.0/29',
              'gateway' => '192.168.2.1',
              'dns' => ['192.168.2.1', '192.168.2.2'],
              'static' => [],
              'reserved' => ['192.168.2.2', '192.168.2.3', '192.168.2.4'],
              'cloud_properties' => {},
              'availability_zone' => 'zone_2',
            }
          ]
        }
      }
      it 'should allocate the least recently released IP' do
        subnet_1_ip_1 = NetAddr::CIDR.create('192.168.1.5')
        ip_repo.add(subnet_1_ip_1, subnet)
        subnet_1_ip_2 = NetAddr::CIDR.create('192.168.1.6')
        ip_repo.add(subnet_1_ip_2, subnet)

        second_subnet = ManualNetworkSubnet.new(network, network_spec['subnets'][1], availability_zones, [], ip_provider_factory)
        subnet_2_ip_1 = NetAddr::CIDR.create('192.168.2.5')
        ip_repo.add(subnet_2_ip_1, second_subnet)
        subnet_2_ip_2 = NetAddr::CIDR.create('192.168.2.6')
        ip_repo.add(subnet_2_ip_2, second_subnet)

        # Release allocated IPs in random order
        ip_repo.delete(subnet_2_ip_1, second_subnet.network.name)
        ip_repo.delete(subnet_1_ip_2, subnet.network.name)
        ip_repo.delete(subnet_1_ip_1, subnet.network.name)
        ip_repo.delete(subnet_2_ip_2, second_subnet.network.name)

        # Verify that re-acquiring the released IPs retains order
        expect(ip_repo.get_dynamic_ip(subnet)).to eq(subnet_1_ip_2)
        ip_repo.add(subnet_1_ip_2, subnet)
        expect(ip_repo.get_dynamic_ip(subnet)).to eq(subnet_1_ip_1)
        ip_repo.add(subnet_1_ip_1, subnet)
        expect(ip_repo.get_dynamic_ip(second_subnet)).to eq(subnet_2_ip_1)
        ip_repo.add(subnet_2_ip_1, second_subnet)
        expect(ip_repo.get_dynamic_ip(second_subnet)).to eq(subnet_2_ip_2)
        ip_repo.add(subnet_2_ip_2, second_subnet)
      end
    end

    context :get_dynamic_ip do
      it 'skips IP in the static range' do
        network_spec['subnets'].first['range'] = '192.168.1.0/30'
        network_spec['subnets'].first['static'] = ['192.168.1.2']

        expect(ip_repo.get_dynamic_ip(subnet)).to be_nil
        end

      it 'skips IP in the reserved range' do
        network_spec['subnets'].first['range'] = '192.168.1.0/30'
        network_spec['subnets'].first['reserved'] = ['192.168.1.2']

        expect(ip_repo.get_dynamic_ip(subnet)).to be_nil
        end

      it 'skips IP that has already been allocated range' do
        network_spec['subnets'].first['range'] = '192.168.1.0/30'

        ip_repo.add('192.168.1.2', subnet)

        expect(ip_repo.get_dynamic_ip(subnet)).to be_nil
      end
    end
  end
end
