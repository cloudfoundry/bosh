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

    describe 'with a database-backed repo' do
      let(:ip_repo) do
        instance_double(
          IpRepo,
          add: nil,
          allocate_vip_ip: ip,
          allocate_dynamic_ip: ip,
        )
      end
      let(:ip) { NetAddr::CIDR.create('1.1.1.1') }
      let(:ip_provider) { IpProvider.new(ip_repo, networks, logger) }

      describe :release do
        context 'when reservation does not have an IP' do
          it 'should raise an error' do
            expect do
              ip_provider.release(ip_reservation)
            end.to raise_error(Bosh::Director::NetworkReservationIpMissing, "Can't release reservation without an IP")
          end

          context 'when reservation is on dynamic network with no IP address' do
            it 'does not fail to release it' do
              dynamic_network = DynamicNetwork.new('my-manual-network', [], logger)
              reservation = BD::DesiredNetworkReservation.new_dynamic(instance_model, dynamic_network)

              expect do
                ip_provider.release(reservation)
              end.to_not raise_error
            end
          end
        end

        context 'when reservation has an IP' do
          it 'should release IP' do
            allow(ip_repo).to receive(:delete)

            reservation = Bosh::Director::DesiredNetworkReservation.new_static(instance_model, manual_network, '192.168.1.2')
            expect do
              ip_provider.release(reservation)
            end.not_to raise_error
            expect(ip_repo).to have_received(:delete)
          end
        end
      end

      describe :reserve_existing_ips do
        context 'when dynamic network' do
          let(:dynamic_network) { BD::DeploymentPlan::DynamicNetwork.new('fake-dynamic-network', [], logger) }
          let(:existing_network_reservation) do
            BD::ExistingNetworkReservation.new(
              instance_model,
              dynamic_network,
              '192.168.1.2',
              'dynamic',
            )
          end

          it 'sets the reservation type to the network type' do
            ip_provider.reserve_existing_ips(existing_network_reservation)
            expect(existing_network_reservation.dynamic?).to be_truthy
          end
        end

        context 'when vip network' do
          let(:existing_network_reservation) do
            BD::ExistingNetworkReservation.new(instance_model, static_vip_network, '69.69.69.69', 'vip')
          end
          let(:static_vip_network) { BD::DeploymentPlan::VipNetwork.parse({ 'name' => 'fake-network' }, [], logger) }

          it 'saves the ip' do
            ip_provider.reserve_existing_ips(existing_network_reservation)
            expect(existing_network_reservation.static?).to be_truthy
            expect(ip_repo).to have_received(:add).with(existing_network_reservation)
          end
        end

        context 'when manual network' do
          let(:existing_network_reservation) do
            BD::ExistingNetworkReservation.new(
              instance_model,
              manual_network,
              '192.168.1.2',
              'manual',
            )
          end

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
                  },
                ],
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
                    },
                  ],
                },
                [],
                logger,
              )
            end

            let(:networks) do
              {
                'my-manual-network' => manual_network,
                'my-another-network' => another_manual_network,
              }
            end

            let(:existing_network_reservation) do
              BD::ExistingNetworkReservation.new(
                instance_model,
                another_manual_network,
                '192.168.1.41',
                'manual',
              )
            end

            it 'should keep existing IP on existing network (it should not switch to a different network)' do
              ip_provider.reserve_existing_ips(existing_network_reservation)

              expect(existing_network_reservation.network.name).to eq('my-another-network')
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
                end

                context 'when that IP is now in the reserved range' do
                  before do
                    manual_network_spec['subnets'].first['range'] = '192.168.1.0/24'
                    manual_network_spec['subnets'].first['reserved'] = ['192.168.1.11']
                  end

                  it 'raises an error' do
                    reservation = BD::DesiredNetworkReservation.new_dynamic(instance_model, manual_network)
                    reservation.resolve_ip(NetAddr::CIDR.create('192.168.1.11').to_i)
                    expect do
                      ip_provider.reserve(reservation)
                    end.to raise_error Bosh::Director::NetworkReservationIpReserved,
                                       "Failed to reserve IP '192.168.1.11' for network 'my-manual-network': IP belongs to "\
                                       'reserved range'
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

              context 'when reservation network has a subnet that includes the reservation IP' do
                it 'saves the ip' do
                  ip_provider.reserve(reservation)
                  expect(ip_repo).to have_received(:add).with(reservation)
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

              context 'when the instance does not specify an az' do
                before do
                  allow(ip_repo).to receive(:allocate_dynamic_ip).and_return(nil, nil, ip)
                end

                it 'tries to allocate an IP in all of the network subnets' do
                  ip_provider.reserve(reservation)

                  expect(ip_repo).to have_received(:allocate_dynamic_ip).exactly(3).times
                end
              end

              context 'when the instance specifies an AZ' do
                before do
                  allow(ip_repo).to receive(:allocate_dynamic_ip).and_return(nil, ip)
                end

                it 'tries to allocate dynamic IPs across multiple subnets that match the az' do
                  instance_model.update(availability_zone: 'az-2')
                  ip_provider.reserve(reservation)

                  expect(ip_repo).to have_received(:allocate_dynamic_ip).twice
                end
              end

              context 'when no subnet has enough capacity to allocate a dynamic IP' do
                let(:ip) { nil }
                it 'raises NetworkReservationNotEnoughCapacity' do
                  expect {
                    ip_provider.reserve(reservation)
                  }.to raise_error BD::NetworkReservationNotEnoughCapacity
                end
              end
            end
          end
        end

        context 'when VipNetwork' do
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

              it 'adds the ip address to the ip repository' do
                ip_provider.reserve(reservation)
                expect(reservation.ip).to eq(NetAddr::CIDR.create('1.1.1.1').to_i)
              end
            end

            context 'when a new reservation is needed' do
              let(:reservation) { BD::DesiredNetworkReservation.new_dynamic(instance_model, vip_network) }

              it 'allocates an ip address for the reservation' do
                ip_provider.reserve(reservation)
                expect(reservation.ip).to eq(NetAddr::CIDR.create('1.1.1.1').to_i)
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
                let(:ip) { nil }

                it 'raises an error' do
                  expect do
                    ip_provider.reserve(reservation)
                  end.to raise_error(Bosh::Director::NetworkReservationNotEnoughCapacity,
                                     /Failed to reserve IP for '.+' for vip network 'my-vip-network': no more available/)
                end
              end
            end
          end

          context 'when IP is provided and can be reserved' do
            it 'reserves the IP as a StaticNetworkReservation' do
              reservation = BD::DesiredNetworkReservation.new_static(instance_model, vip_network, '192.168.1.2')

              expect do
                ip_provider.reserve(reservation)
              end.not_to raise_error
            end
          end
        end
      end
    end
  end
end
