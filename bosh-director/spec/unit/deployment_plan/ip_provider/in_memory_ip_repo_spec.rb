require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe InMemoryIpRepo do
    let(:restricted_ips) { [] }
    let(:static_ips) { [] }
    let(:ip_repo) { InMemoryIpRepo.new(logger) }
    let(:ip_address) { NetAddr::CIDR.create('192.168.1.5') }
    let(:subnet) { ManualNetworkSubnet.parse(network.name, network_spec['subnets'].first, availability_zones, []) }
    let(:network) do
      BD::DeploymentPlan::ManualNetwork.parse(
        network_spec,
        availability_zones,
        global_network_resolver,
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
            'az' => 'zone_1',
          }
        ]
      }
    }
    let(:global_network_resolver) { instance_double(BD::DeploymentPlan::GlobalNetworkResolver, reserved_legacy_ranges: []) }
    let(:ip_provider_factory) { BD::DeploymentPlan::IpProviderFactory.new(logger, {}) }
    let(:network_name) { network_spec['name'] }
    let(:instance_model) { BD::Models::Instance.make }
    let(:reservation) { BD::DesiredNetworkReservation.new_dynamic(instance_model, network) }

    describe :add do
      context 'when IP was already added in that subnet' do
        before do
          reservation.resolve_ip(ip_address)
          ip_repo.add(reservation)
        end

        it 'raises an error' do
          message = "Failed to reserve IP '192.168.1.5' for '#{network_name}': already reserved"
          expect {
            ip_repo.add(reservation)
          }.to raise_error(BD::NetworkReservationAlreadyInUse, message)
        end
      end

      context 'when IP is valid' do
        it 'adds the IP' do
          reservation.resolve_ip(ip_address)
          ip_repo.add(reservation)

          expect {
            ip_repo.add(reservation)
          }.to raise_error BD::NetworkReservationAlreadyInUse
        end
      end
    end

    describe :delete do
      it 'should delete IPs' do
        reservation.resolve_ip(ip_address)
        ip_repo.add(reservation)

        expect {
          ip_repo.add(reservation)
        }.to raise_error BD::NetworkReservationAlreadyInUse

        ip_repo.delete(ip_address, network_name)

        expect {
          ip_repo.add(reservation)
        }.to_not raise_error
      end
    end

    context 'when IP is a Fixnum' do
      let(:ip_address_to_i) { NetAddr::CIDR.create('192.168.1.3').to_i }
      it 'adds and deletes IPs' do
        reservation.resolve_ip(ip_address_to_i)
        ip_repo.add(reservation)

        expect {
          ip_repo.add(reservation)
        }.to raise_error BD::NetworkReservationAlreadyInUse

        ip_repo.delete(ip_address_to_i, network_name)

        expect {
          ip_repo.add(reservation)
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
              'az' => 'zone_1',
            },
            {
              'range' => '192.168.2.0/29',
              'gateway' => '192.168.2.1',
              'dns' => ['192.168.2.1', '192.168.2.2'],
              'static' => [],
              'reserved' => ['192.168.2.2', '192.168.2.3', '192.168.2.4'],
              'cloud_properties' => {},
              'az' => 'zone_2',
            }
          ]
        }
      }

      it 'should allocate the least recently released IP' do
        subnet_1_ip_1 = NetAddr::CIDR.create('192.168.1.5')
        reservation.resolve_ip(subnet_1_ip_1)
        ip_repo.add(reservation)

        subnet_1_ip_2 = NetAddr::CIDR.create('192.168.1.6')
        reservation.resolve_ip(subnet_1_ip_2)
        ip_repo.add(reservation)

        subnet_2_ip_1 = NetAddr::CIDR.create('192.168.2.5')
        reservation.resolve_ip(subnet_2_ip_1)
        ip_repo.add(reservation)

        subnet_2_ip_2 = NetAddr::CIDR.create('192.168.2.6')
        reservation.resolve_ip(subnet_2_ip_2)
        ip_repo.add(reservation)

        second_subnet = ManualNetworkSubnet.parse(network.name, network_spec['subnets'][1], availability_zones, [])

        # Release allocated IPs in random order
        ip_repo.delete(subnet_2_ip_1, network_name)
        ip_repo.delete(subnet_1_ip_2, network_name)
        ip_repo.delete(subnet_1_ip_1, network_name)
        ip_repo.delete(subnet_2_ip_2, network_name)

        # Verify that re-acquiring the released IPs retains order
        expect(ip_repo.allocate_dynamic_ip(reservation, subnet)).to eq(subnet_1_ip_2)
        expect(ip_repo.allocate_dynamic_ip(reservation, subnet)).to eq(subnet_1_ip_1)
        expect(ip_repo.allocate_dynamic_ip(reservation, second_subnet)).to eq(subnet_2_ip_1)
        expect(ip_repo.allocate_dynamic_ip(reservation, second_subnet)).to eq(subnet_2_ip_2)
      end
    end

    context :allocate_dynamic_ip do
      it 'skips IP in the static range' do
        network_spec['subnets'].first['range'] = '192.168.1.0/30'
        network_spec['subnets'].first['static'] = ['192.168.1.2']

        expect(ip_repo.allocate_dynamic_ip(reservation, subnet)).to be_nil
        end

      it 'skips IP in the reserved range' do
        network_spec['subnets'].first['range'] = '192.168.1.0/30'
        network_spec['subnets'].first['reserved'] = ['192.168.1.2']

        expect(ip_repo.allocate_dynamic_ip(reservation, subnet)).to be_nil
        end

      it 'skips IP that has already been allocated' do
        network_spec['subnets'].first['range'] = '192.168.1.0/30'

        expect(ip_repo.allocate_dynamic_ip(reservation, subnet)).to eq('192.168.1.2')
        expect(ip_repo.allocate_dynamic_ip(reservation, subnet)).to be_nil
      end
    end
  end
end
