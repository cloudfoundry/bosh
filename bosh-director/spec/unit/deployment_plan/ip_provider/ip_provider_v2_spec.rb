require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe IpProviderV2 do
    let(:in_memory_ip_repo) { InMemoryIpRepo.new(logger) }
    let(:ip_provider) { IpProviderV2.new(in_memory_ip_repo, false, logger) }
    let(:instance) { double(:instance) }
    let(:deployment_plan) { instance_double(Planner, using_global_networking?: true, name: 'fake-deployment') }
    let(:global_network_resolver) { GlobalNetworkResolver.new(deployment_plan) }
    let(:ip_provider_factory) { IpProviderFactory.new(logger, {}) }
    let(:network_spec) {
      {
        'name' => 'my-network',
        'subnets' => [
          {
            'range' => '192.168.1.0/30',
            'gateway' => '192.168.1.1',
            'dns' => ['192.168.1.1', '192.168.1.2'],
            'static' => [],
            'reserved' => [],
            'cloud_properties' => {},
            'availability_zone' => 'az-1',
          },
          {
            'range' => '192.168.2.0/30',
            'gateway' => '192.168.2.1',
            'dns' => ['192.168.2.1', '192.168.2.2'],
            'static' => [],
            'reserved' => [],
            'cloud_properties' => {},
            'availability_zone' => 'az-2',
          },
          {
            'range' => '192.168.3.0/30',
            'gateway' => '192.168.3.1',
            'dns' => ['192.168.3.1', '192.168.3.2'],
            'static' => [],
            'reserved' => [],
            'cloud_properties' => {},
            'availability_zone' => 'az-2',
          }

        ]
      }
    }
    let(:manual_network) do
      ManualNetwork.new(
        network_spec,
        [
          BD::DeploymentPlan::AvailabilityZone.new('az-1', {}),
          BD::DeploymentPlan::AvailabilityZone.new('az-2', {})
        ],
        global_network_resolver,
        ip_provider_factory,
        logger
      )
    end
    let(:ip_reservation) { Bosh::Director::DynamicNetworkReservation.new(instance, manual_network) }

    describe :release do
      context 'when reservation does not have an IP' do
        it 'should raise an error' do
          expect {
            ip_provider.release(ip_reservation)
          }.to raise_error(Bosh::Director::NetworkReservationIpMissing, "Can't release reservation without an IP")
        end
      end

      context 'IP is within subnet and not nil' do
        it 'should release IP' do
          allow(instance).to receive(:availability_zone).and_return(BD::DeploymentPlan::AvailabilityZone.new('az-2', {}))

          ip_provider.reserve(ip_reservation)
          expect {
            ip_provider.reserve(ip_reservation)
          }.to raise_error(Bosh::Director::NetworkReservationAlreadyInUse)

          ip_provider.release(ip_reservation)

          expect {
            ip_provider.reserve(ip_reservation)
          }.not_to raise_error
        end
      end
    end

    describe :reserve do
      context 'when IP is provided' do
        context 'when it does not belong to any subnet' do
          context 'when existing network reservation' do
            let(:reservation) { BD::ExistingNetworkReservation.new(instance, manual_network, '192.168.2.6') }

            it 'does not raises error' do
              expect {
                ip_provider.reserve(reservation)
              }.to_not raise_error
            end
          end

          context 'when dynamic network reservation' do
            let(:reservation) { BD::DynamicNetworkReservation.new(instance, manual_network) }
            before { reservation.resolve_ip('192.168.2.6') }

            it 'raises NetworkReservationIpOutsideSubnet' do
              expect {
                ip_provider.reserve(reservation)
              }.to raise_error BD::NetworkReservationIpOutsideSubnet
            end
          end

          context 'when static network reservation' do
            let(:reservation) { BD::StaticNetworkReservation.new(instance, manual_network, '192.168.2.6') }

            it 'raises NetworkReservationIpOutsideSubnet' do
              expect {
                ip_provider.reserve(reservation)
              }.to raise_error BD::NetworkReservationIpOutsideSubnet
            end
          end
        end

        context 'when IP belongs to subnet' do
          context 'when it is a dynamic reservation' do
            it 'reserves reservation' do
              network_spec['subnets'].first['range'] = '192.168.1.0/24'

              reservation = BD::DynamicNetworkReservation.new(instance, manual_network)

              reservation.resolve_ip('192.168.1.6')

              allow(instance).to receive(:availability_zone).and_return(BD::DeploymentPlan::AvailabilityZone.new('az-1', {}))

              ip_provider.reserve(reservation)
              expect(reservation.ip).to eq(NetAddr::CIDR.create('192.168.1.6').to_i)
              expect(reservation).to be_reserved
            end

            context 'when that IP is now in the reserved range' do
              before do
                network_spec['subnets'].first['range'] = '192.168.1.0/24'
                network_spec['subnets'].first['reserved'] = ['192.168.1.11']
              end

              it 'raises an error' do
                reservation = BD::DynamicNetworkReservation.new(instance, manual_network)
                reservation.resolve_ip(NetAddr::CIDR.create('192.168.1.11').to_i)
                expect {
                  ip_provider.reserve(reservation)
                }.to raise_error Bosh::Director::NetworkReservationIpReserved,
                    "Failed to reserve IP '192.168.1.11' for network 'my-network': IP belongs to reserved range"
              end
            end
          end

          context 'when it is a static reservation' do
            before do
              network_spec['subnets'].first['range'] = '192.168.1.0/24'
              network_spec['subnets'].first['static'] = ['192.168.1.5']
            end
            let(:static_network_reservation) { BD::StaticNetworkReservation.new(instance, manual_network, NetAddr::CIDR.create('192.168.1.5').to_i) }

            it 'should reserve static IPs' do
              expect {
                ip_provider.reserve(static_network_reservation)
              }.to_not raise_error
            end

            it 'should fail to reserve the IP if it was already reserved' do
              ip_provider.reserve(static_network_reservation)
              expect {
                ip_provider.reserve(static_network_reservation)
              }.to raise_error BD::NetworkReservationAlreadyInUse
            end

            context 'when IP is in reserved range' do
              before do
                network_spec['subnets'].first['range'] = '192.168.1.0/24'
                network_spec['subnets'].first['reserved'] = ['192.168.1.11']
              end

              it 'when IP is in reserved range, raises NetworkReservationIpReserved' do
                reservation = BD::StaticNetworkReservation.new(instance, manual_network, NetAddr::CIDR.create('192.168.1.11').to_i)
                expect {
                  ip_provider.reserve(reservation)
                }.to raise_error Bosh::Director::NetworkReservationIpReserved,
                    "Failed to reserve IP '192.168.1.11' for network 'my-network': IP belongs to reserved range"
              end
            end
          end

          context 'when it is an existing network reservation' do
            let(:existing_network_reservation) {BD::ExistingNetworkReservation.new(instance, manual_network, NetAddr::CIDR.create('192.168.1.2').to_i)}
            context 'when IP is in the static range' do
              it 'should reserve it as a StaticNetworkReservation' do
                network_spec['subnets'].first['static'] = ['192.168.1.2']

                ip_provider.reserve(existing_network_reservation)

                expect(existing_network_reservation.reserved_as?(BD::StaticNetworkReservation)).to be_truthy
              end
            end

            context 'when IP is NOT in the static range' do
              context 'when IP is NOT in the reserved range'
              it 'should reserve it as a DynamicNetworkReservation' do
                ip_provider.reserve(existing_network_reservation)

                expect(existing_network_reservation.reserved_as?(BD::DynamicNetworkReservation)).to be_truthy
              end
            end

            context 'when IP is in the reserved range'
            it 'should not reserve the IP' do
              network_spec['subnets'].first['reserved'] = ['192.168.1.2']

              ip_provider.reserve(existing_network_reservation)

              expect(existing_network_reservation).not_to be_reserved
            end
          end
        end
      end

      context 'when IP is not provided' do
        context 'for dynamic reservation' do
          let(:reservation) { BD::DynamicNetworkReservation.new(instance, manual_network) }

          it 'allocates a dynamic IP in the correct subnet when the instance has an AZ' do
            allow(instance).to receive(:availability_zone).and_return(BD::DeploymentPlan::AvailabilityZone.new('az-2', {}))
            ip_provider.reserve(reservation)

            expect(NetAddr::CIDR.create(reservation.ip).to_s).to eq('192.168.2.2/32')
          end

          it 'allocates a dynamic IP in any subnet for an instance without an AZ' do
            allow(instance).to receive(:availability_zone).and_return(nil)
            ip_provider.reserve(reservation)

            expect(NetAddr::CIDR.create(reservation.ip).to_s).to eq('192.168.1.2/32')
          end

          it 'does not allocate a static IP as a dynamic IP' do
            allow(instance).to receive(:availability_zone).and_return(nil)
            network_spec['subnets'].first['static'] << '192.168.1.2'

            ip_provider.reserve(reservation)

            expect(NetAddr::CIDR.create(reservation.ip).to_s).to eq('192.168.2.2/32')
          end

          it 'does not allocate a reserved IP as a dynamic IP' do
            allow(instance).to receive(:availability_zone).and_return(nil)
            network_spec['subnets'].first['reserved'] << '192.168.1.2'

            ip_provider.reserve(reservation)

            expect(NetAddr::CIDR.create(reservation.ip).to_s).to eq('192.168.2.2/32')
          end

          it 'allocates dynamic IPs across multiple subnets for a single AZ' do
            allow(instance).to receive(:availability_zone).and_return(BD::DeploymentPlan::AvailabilityZone.new('az-2', {}))
            ip_provider.reserve(BD::DynamicNetworkReservation.new(instance, manual_network))

            ip_provider.reserve(reservation)
            expect(NetAddr::CIDR.create(reservation.ip).to_s).to eq('192.168.3.2/32')
          end

          context 'when no subnet has enough capacity to allocate a dynamic IP' do
            it 'raises NetworkReservationNotEnoughCapacity' do
              allow(instance).to receive(:availability_zone).and_return(nil)
              # Trying to reserve 1 more IP than the available
              3.times { ip_provider.reserve(BD::DynamicNetworkReservation.new(instance, manual_network)) }

              expect {
                ip_provider.reserve(reservation)
              }.to raise_error BD::NetworkReservationNotEnoughCapacity
            end
          end
        end
      end
    end
  end
end
