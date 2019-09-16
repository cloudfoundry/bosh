require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe IpProvider do
    let(:instance_model) { Bosh::Director::Models::Instance.make }
    let(:deployment_plan) { instance_double(Planner, name: 'fake-deployment') }
    let(:networks) do
      { 'my-manual-network' => manual_network }
    end
    let(:manual_network_spec) do
      {
        'name' => 'my-manual-network',
        'subnets' => [
          {
            'range' => '192.168.1.0/30',
            'gateway' => '192.168.1.1',
            'dns' => ['192.168.1.1', '192.168.1.2'],
            'static' => [],
            'reserved' => [],
            'cloud_properties' => {},
            'az' => 'az-1',
          },
          {
            'range' => '192.168.2.0/30',
            'gateway' => '192.168.2.1',
            'dns' => ['192.168.2.1', '192.168.2.2'],
            'static' => [],
            'reserved' => [],
            'cloud_properties' => {},
            'az' => 'az-2',
          },
          {
            'range' => '192.168.3.0/30',
            'gateway' => '192.168.3.1',
            'dns' => ['192.168.3.1', '192.168.3.2'],
            'static' => [],
            'reserved' => [],
            'cloud_properties' => {},
            'azs' => ['az-2'],
          },
        ],
      }
    end
    let(:manual_network) do
      ManualNetwork.parse(
        manual_network_spec,
        [
          BD::DeploymentPlan::AvailabilityZone.new('az-1', {}),
          BD::DeploymentPlan::AvailabilityZone.new('az-2', {})
        ],
        logger
      )
    end
    let(:another_manual_network) do
      ManualNetwork.parse(
        {
          'name' => 'my-another-network',
          'subnets' => [
            {
              'range' => '192.168.1.0/24',
              'gateway' => '192.168.1.1',
            }
          ]
        },
        [],
        logger
      )
    end
    let(:vip_network_spec) do
      {
        'name' => 'my-vip-network',
        'type' => 'vip',
      }
    end
    let(:vip_network) { VipNetwork.parse(vip_network_spec, [], logger) }
    let(:ip_reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, manual_network) }

    before do
      Bosh::Director::Config.current_job = Bosh::Director::Jobs::BaseJob.new
      Bosh::Director::Config.current_job.task_id = 'fake-task-id'
    end

    shared_examples_for 'an ip provider with any repo' do
      describe :release do
        context 'when reservation does not have an IP' do
          it 'should raise an error' do
            ip_reservation.mark_reserved

            expect {
              ip_provider.release(ip_reservation)
            }.to raise_error(Bosh::Director::NetworkReservationIpMissing, "Can't release reservation without an IP")
          end
        end

        context 'when reservation has an IP' do
          it 'should release IP' do
            manual_network_spec['subnets'].first['static'] = ['192.168.1.2']
            instance_model = Bosh::Director::Models::Instance.make(availability_zone: 'az-2')
            other_instance_model = Bosh::Director::Models::Instance.make(availability_zone: 'az-2')

            original_reservation = Bosh::Director::DesiredNetworkReservation.new_static(instance_model, manual_network, '192.168.1.2')
            new_reservation = Bosh::Director::DesiredNetworkReservation.new_static(other_instance_model, manual_network, '192.168.1.2')

            ip_provider.reserve(original_reservation)
            expect {
              ip_provider.reserve(new_reservation)
            }.to raise_error(Bosh::Director::NetworkReservationAlreadyInUse)

            ip_provider.release(original_reservation)

            expect {
              ip_provider.reserve(new_reservation)
            }.not_to raise_error
          end

          context 'when the IP is from a previous deploy and no longer in any subnets range' do
            it 'should release IP' do
              manual_network_spec['subnets'].first['range'] = '192.168.6.0/30'
              manual_network_spec['subnets'].first['gateway'] = '192.168.6.1'
              manual_network_spec['subnets'].first['dns'] = []

              reservation_with_ip_outside_subnet = Bosh::Director::DesiredNetworkReservation.new_static(instance_model, manual_network, '192.168.1.2')
              expect {
                ip_provider.release(reservation_with_ip_outside_subnet)
              }.not_to raise_error
            end
          end

          context 'when VipNetwork' do
            it 'releases IP' do
              reservation = BD::DesiredNetworkReservation.new_static(instance_model, vip_network, '192.168.1.2')
              other_instance_model = Bosh::Director::Models::Instance.make(availability_zone: 'az-2')
              other_reservation_with_same_ip = BD::DesiredNetworkReservation.new_static(other_instance_model, vip_network, '192.168.1.2')

              ip_provider.reserve(reservation)
              expect {
                ip_provider.reserve(other_reservation_with_same_ip)
              }.to raise_error

              ip_provider.release(reservation)
              expect { ip_provider.reserve(other_reservation_with_same_ip) }.not_to raise_error
            end
          end

          context 'when user switches network type from manual to dynamic AND deployment had a previous static IP reservation' do
            it 'releases IP' do
              manual_network_spec['subnets'].first['static'] = ['192.168.1.2']
              reservation = BD::DesiredNetworkReservation.new_static(instance_model, manual_network, '192.168.1.2')
              ip_provider.reserve(reservation)

              dynamic_network = DynamicNetwork.new('my-manual-network', [], logger)
              reservation = BD::ExistingNetworkReservation.new(instance_model, dynamic_network, '192.168.1.2', 'manual')
              ip_provider.reserve_existing_ips(reservation)

              other_instance_model = Bosh::Director::Models::Instance.make(availability_zone: 'az-2')
              other_reservation_with_same_ip = BD::DesiredNetworkReservation.new_static(other_instance_model, manual_network, '192.168.1.2')

              expect {
                ip_provider.reserve(other_reservation_with_same_ip)
              }.to raise_error

              ip_provider.release(reservation)
              expect { ip_provider.reserve(other_reservation_with_same_ip) }.not_to raise_error
            end
          end

          context 'when reservation is on dynamic network without IP address' do
            it 'does not fail to release it' do
              dynamic_network = DynamicNetwork.new('my-manual-network', [], logger)
              reservation = BD::DesiredNetworkReservation.new_dynamic(instance_model, dynamic_network)

              expect {
                ip_provider.release(reservation)
              }.to_not raise_error
            end
          end
        end
      end

      describe :reserve do
        context 'when ManualNetwork' do
          context 'when IP is provided' do
            context 'when reservation does not belong to any subnet' do
              context 'when dynamic network reservation' do
                let(:reservation) { BD::DesiredNetworkReservation.new_dynamic(instance_model, manual_network) }
                before { reservation.resolve_ip('192.168.2.6') }

                it 'raises NetworkReservationIpOutsideSubnet' do
                  expect {
                    ip_provider.reserve(reservation)
                  }.to raise_error BD::NetworkReservationIpOutsideSubnet
                end
              end

              context 'when static network reservation' do
                let(:reservation) { BD::DesiredNetworkReservation.new_static(instance_model, manual_network, '192.168.2.6') }

                it 'raises NetworkReservationIpOutsideSubnet' do
                  expect {
                    ip_provider.reserve(reservation)
                  }.to raise_error BD::NetworkReservationIpOutsideSubnet
                end
              end
            end

            context 'when reservation belongs to subnet' do
              context 'when it is a dynamic reservation' do
                it 'reserves reservation' do
                  manual_network_spec['subnets'].first['range'] = '192.168.1.0/24'

                  reservation = BD::DesiredNetworkReservation.new_dynamic(instance_model, manual_network)

                  reservation.resolve_ip('192.168.1.6')
                  reservation.instance_model.update(availability_zone: 'az-1')

                  ip_provider.reserve(reservation)
                  expect(reservation.ip).to eq(NetAddr::CIDR.create('192.168.1.6').to_i)
                  expect(reservation).to be_reserved
                end

                context 'when that IP is now in the reserved range' do
                  before do
                    manual_network_spec['subnets'].first['range'] = '192.168.1.0/24'
                    manual_network_spec['subnets'].first['reserved'] = ['192.168.1.11']
                  end

                  it 'raises an error' do
                    reservation = BD::DesiredNetworkReservation.new_dynamic(instance_model, manual_network)
                    reservation.resolve_ip(NetAddr::CIDR.create('192.168.1.11').to_i)
                    expect {
                      ip_provider.reserve(reservation)
                    }.to raise_error Bosh::Director::NetworkReservationIpReserved,
                        "Failed to reserve IP '192.168.1.11' for network 'my-manual-network': IP belongs to reserved range"
                  end
                end

                context 'when user accidentally includes a static IP in the range' do
                  it 'raises an error' do
                    manual_network_spec['subnets'].first['static'] = ['192.168.1.2']

                    reservation = BD::DesiredNetworkReservation.new_dynamic(instance_model, manual_network)
                    reservation.resolve_ip('192.168.1.2')
                    expect {
                      ip_provider.reserve(reservation)
                    }.to raise_error Bosh::Director::NetworkReservationWrongType,
                        "IP '192.168.1.2' on network 'my-manual-network' does not belong to dynamic pool"
                  end
                end
              end

              context 'when it is a static reservation' do
                before do
                  manual_network_spec['subnets'].first['range'] = '192.168.1.0/24'
                  manual_network_spec['subnets'].first['static'] = ['192.168.1.5']
                end
                let(:static_network_reservation) { BD::DesiredNetworkReservation.new_static(instance_model, manual_network, '192.168.1.5') }

                it 'should reserve static IPs' do
                  expect {
                    ip_provider.reserve(static_network_reservation)
                  }.to_not raise_error
                end

                context 'when IP is in reserved range' do
                  before do
                    manual_network_spec['subnets'].first['range'] = '192.168.1.0/24'
                    manual_network_spec['subnets'].first['reserved'] = ['192.168.1.11']
                  end

                  it 'when IP is in reserved range, raises NetworkReservationIpReserved' do
                    reservation = BD::DesiredNetworkReservation.new_static(instance_model, manual_network, '192.168.1.11')
                    expect {
                      ip_provider.reserve(reservation)
                    }.to raise_error Bosh::Director::NetworkReservationIpReserved,
                        "Failed to reserve IP '192.168.1.11' for network 'my-manual-network': IP belongs to reserved range"
                  end
                end

                context 'when user accidentally assigns an IP to a job that is NOT a static IP' do
                  it 'raises an error' do
                    manual_network_spec['subnets'].first['static'] = ['192.168.1.2']
                    reservation = BD::DesiredNetworkReservation.new_dynamic(instance_model, manual_network)
                    reservation.resolve_ip('192.168.1.2')
                    expect {
                      ip_provider.reserve(reservation)
                    }.to raise_error Bosh::Director::NetworkReservationWrongType,
                        "IP '192.168.1.2' on network 'my-manual-network' does not belong to dynamic pool"
                  end
                end
              end
            end

            context 'when there are several networks that have overlapping subnet ranges that include reservation IP' do
              let(:networks) do
                {
                  'my-manual-network' => manual_network,
                  'my-another-network' => another_manual_network,
                }
              end
              let(:reservation) do
                reservation = BD::DesiredNetworkReservation.new_dynamic(instance_model, manual_network)
                reservation.resolve_ip('192.168.1.6')
                reservation
              end
              let(:manual_network_spec) do
                {
                  'name' => 'my-manual-network',
                  'subnets' => [
                    {
                      'range' => '192.168.1.0/24',
                      'gateway' => '192.168.1.1',
                      'reserved' => manual_network_reserved,
                    }
                  ]
                }
              end
              let(:manual_network_reserved) { [] }

              context 'when reservation network has subnet that includes reservation IP' do
                it 'marks reservation as reserved' do
                  ip_provider.reserve(reservation)
                  expect(reservation).to be_reserved
                  expect(reservation.network.name).to eq('my-manual-network')
                end
              end

              context 'when reservation network does not have subnet that includes reservation IP' do
                let(:manual_network_reserved) { ['192.168.1.6'] }
                it 'fails to reserve the reservation' do
                  expect {
                    ip_provider.reserve(reservation)
                  }.to raise_error BD::NetworkReservationIpReserved, "Failed to reserve IP '192.168.1.6' for network 'my-manual-network': IP belongs to reserved range"
                end
              end
            end
          end

          context 'when IP is not provided' do
            context 'for dynamic reservation' do
              let(:reservation) { BD::DesiredNetworkReservation.new_dynamic(instance_model, manual_network) }

              it 'allocates a dynamic IP in the correct subnet when the instance has an AZ' do
                instance_model.update(availability_zone: 'az-2')
                ip_provider.reserve(reservation)

                expect(NetAddr::CIDR.create(reservation.ip).to_s).to eq('192.168.2.2/32')
              end

              it 'allocates a dynamic IP in any subnet for an instance without an AZ' do
                ip_provider.reserve(reservation)

                expect(NetAddr::CIDR.create(reservation.ip).to_s).to eq('192.168.1.2/32')
              end

              it 'does not allocate a static IP as a dynamic IP' do
                manual_network_spec['subnets'].first['static'] << '192.168.1.2'

                ip_provider.reserve(reservation)

                expect(NetAddr::CIDR.create(reservation.ip).to_s).not_to eq('192.168.1.2/32')
              end

              it 'does not allocate a reserved IP as a dynamic IP' do
                manual_network_spec['subnets'].first['reserved'] << '192.168.1.2'

                ip_provider.reserve(reservation)

                expect(NetAddr::CIDR.create(reservation.ip).to_s).not_to eq('192.168.1.2/32')
              end

              it 'allocates dynamic IPs across multiple subnets for a single AZ' do
                instance_model.update(availability_zone: 'az-2')
                ip_provider.reserve(BD::DesiredNetworkReservation.new_dynamic(instance_model, manual_network))

                ip_provider.reserve(reservation)
                expect(NetAddr::CIDR.create(reservation.ip).to_s).to eq('192.168.3.2/32')
              end

              context 'when no subnet has enough capacity to allocate a dynamic IP' do
                it 'raises NetworkReservationNotEnoughCapacity' do
                  # Trying to reserve 1 more IP than the available
                  3.times { ip_provider.reserve(BD::DesiredNetworkReservation.new_dynamic(instance_model, manual_network)) }

                  expect {
                    ip_provider.reserve(reservation)
                  }.to raise_error BD::NetworkReservationNotEnoughCapacity
                end
              end
            end
          end
        end

        context 'when VipNetwork' do
          context 'when IP has already been reserved (allocated)' do
            it 'raises NetworkReservationAlreadyInUse' do
              other_instance_model = Bosh::Director::Models::Instance.make(availability_zone: 'az-2')

              original_static_network_reservation = BD::DesiredNetworkReservation.new_static(instance_model, vip_network, '192.168.1.2')
              new_static_network_reservation = BD::DesiredNetworkReservation.new_static(other_instance_model, vip_network, '192.168.1.2')

              ip_provider.reserve(original_static_network_reservation)

              expect {
                ip_provider.reserve(new_static_network_reservation)
              }.to raise_error BD::NetworkReservationAlreadyInUse
            end
          end

          context 'when IP is provided and can be reserved' do
            it 'reserves the IP as a StaticNetworkReservation' do
              reservation = BD::DesiredNetworkReservation.new_static(instance_model, vip_network, '192.168.1.2')

              expect {
                ip_provider.reserve(reservation)
              }.not_to raise_error
            end
          end
        end
      end

      describe :reserve_existing_ips do
        context 'when dynamic network' do
          let(:dynamic_network) { BD::DeploymentPlan::DynamicNetwork.new('fake-dynamic-network', [], logger) }

          context 'when existing network type was dynamic' do
            let(:existing_network_reservation) { BD::ExistingNetworkReservation.new(instance_model, dynamic_network, '192.168.1.2', 'dynamic') }

            it 'does not reserve the reservation' do
              ip_provider.reserve_existing_ips(existing_network_reservation)
              expect(existing_network_reservation.dynamic?).to be_truthy
              expect(existing_network_reservation.reserved?).to be_truthy
            end
          end

          context 'when existing network type was not dynamic' do
            let(:existing_network_reservation) { BD::ExistingNetworkReservation.new(instance_model, dynamic_network, '192.168.1.2', 'manual') }

            it 'does not reserve the reservation' do
              ip_provider.reserve_existing_ips(existing_network_reservation)
              expect(existing_network_reservation.dynamic?).to be_falsey
              expect(existing_network_reservation.reserved?).to be_falsey
            end
          end
        end

        context 'when vip network' do
          let(:existing_network_reservation) do
            BD::ExistingNetworkReservation.new(instance_model, static_vip_network, '69.69.69.69', 'vip')
          end
          let(:static_vip_network) { BD::DeploymentPlan::VipNetwork.parse({ 'name' => 'fake-network' }, [], logger) }

          it 'marks reservation as reserved' do
            ip_provider.reserve_existing_ips(existing_network_reservation)
            expect(existing_network_reservation.static?).to be_truthy
            expect(existing_network_reservation.reserved?).to be_truthy
          end
        end

        context 'when manual network' do
          let(:existing_network_reservation) { BD::ExistingNetworkReservation.new(instance_model, manual_network, '192.168.1.2', 'manual') }

          context 'when IP is a static IP' do
            it 'should reserve IP as static' do
              manual_network_spec['subnets'].first['static'] = ['192.168.1.2']
              ip_provider.reserve_existing_ips(existing_network_reservation)

              expect(existing_network_reservation.static?).to be_truthy
            end
          end

          context 'when IP is a dynamic IP' do
            it 'should reserve IP as dynamic' do
              ip_provider.reserve_existing_ips(existing_network_reservation)

              expect(existing_network_reservation.dynamic?).to be_truthy
            end
          end

          context 'when IP is in reserved range' do
            it 'should not reserve IP' do
              manual_network_spec['subnets'].first['reserved'] = ['192.168.1.2']
              ip_provider.reserve_existing_ips(existing_network_reservation)

              expect(existing_network_reservation).not_to be_reserved
            end
          end

          context 'when reservation network has subnet that includes reservation IP' do
            it 'reserves IP' do
              ip_provider.reserve_existing_ips(existing_network_reservation)
              expect(existing_network_reservation).to be_reserved
            end
          end

          context 'when there are 2 networks with the same subnet but different reserved ranges' do
            let(:manual_network_spec) do
              {
                'name' => 'my-manual-network',
                'subnets' => [
                  {
                    'range' => '192.168.1.0/24',
                    'gateway' => '192.168.1.1',
                    'dns' => ['192.168.1.1', '192.168.1.2'],
                    'reserved' => ['192.168.1.2-192.168.1.30'],
                  }
                ]
              }
            end

            let(:another_manual_network) do
              ManualNetwork.parse(
                {
                  'name' => 'my-another-network',
                  'subnets' => [
                    {
                      'range' => '192.168.1.0/24',
                      'gateway' => '192.168.1.1',
                      'dns' => ['192.168.1.1', '192.168.1.2'],
                      'reserved' => ['192.168.1.2-192.168.1.40'],
                    }
                  ]
                },
                [],
                logger
              )
            end

            let(:networks) do
              {
                'my-manual-network' => manual_network,
                'my-another-network' => another_manual_network,
              }
            end

            let(:existing_network_reservation) { BD::ExistingNetworkReservation.new(instance_model, another_manual_network, '192.168.1.41', 'manual') }

            it 'should keep existing IP on existing network (it should not switch to a different network)' do
              ip_provider.reserve_existing_ips(existing_network_reservation)

              expect(existing_network_reservation.network.name).to eq('my-another-network')
            end
          end
        end
      end
    end

    describe 'with a database-backed repo' do
      let(:ip_repo) { IpRepo.new(logger) }
      let(:ip_provider) { IpProvider.new(ip_repo, networks, logger) }

      it_should_behave_like 'an ip provider with any repo'

      describe :reserve do
        context 'when globally allocating vips' do
          let(:vip_network_spec) do
            {
              'name' => 'my-vip-network',
              'type' => 'vip',
              'subnets' => [
                {
                  'static' => ['1.1.1.1', '2.2.2.2'],
                },
                {
                  'static' => ['3.3.3.3', '4.4.4.4'],
                },
              ],
            }
          end

          context 'when the reservation already exists' do
            let(:reservation) do
              BD::ExistingNetworkReservation.new(
                instance_model,
                vip_network,
                '1.1.1.1',
                'vip',
              )
            end

            it 'adds the ip address to the ip repository and marks the reservation as reserved' do
              ip_provider.reserve(reservation)
              expect(reservation.ip).to eq(NetAddr::CIDR.create('1.1.1.1').to_i)
              expect(reservation).to be_reserved
            end
          end

          context 'when a new reservation is needed' do
            let(:reservation) { BD::DesiredNetworkReservation.new_dynamic(instance_model, vip_network) }

            it 'allocates an ip address for the reservation and marks the reservation as resrved' do
              ip_provider.reserve(reservation)
              expect(reservation.ip).to eq(NetAddr::CIDR.create('1.1.1.1').to_i)
              expect(reservation).to be_reserved
            end

            context 'and there are no available vips' do
              let(:vip_network_spec) do
                {
                  'name' => 'my-vip-network',
                  'type' => 'vip',
                  'subnets' => [
                    {
                      'static' => [],
                    },
                  ],
                }
              end

              it 'raises an error' do
                expect do
                  ip_provider.reserve(reservation)
                end.to raise_error
              end
            end
          end
        end
      end

      describe :reserve_existing_ips do
        context 'when ExistingNetworkReservation' do
          let(:existing_network_reservation) { BD::ExistingNetworkReservation.new(instance_model, manual_network, '192.168.1.2', 'manual') }

          it 'fails when trying to reserve for another instance' do
            ip_provider.reserve_existing_ips(existing_network_reservation)

            other_instance_model = Bosh::Director::Models::Instance.make
            new_reservation_wanting_existing_ip = BD::DesiredNetworkReservation.new_dynamic(other_instance_model, manual_network)
            new_reservation_wanting_existing_ip.resolve_ip('192.168.1.2')

            expect {
              ip_provider.reserve_existing_ips(new_reservation_wanting_existing_ip)
            }.to raise_error /already reserved/
          end
        end
      end
    end
  end
end
