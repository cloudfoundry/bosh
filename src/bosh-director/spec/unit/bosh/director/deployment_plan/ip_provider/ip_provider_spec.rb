require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe IpProvider do
      include IpUtil
      let(:instance_model) { FactoryBot.create(:models_instance) }
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
            Bosh::Director::DeploymentPlan::AvailabilityZone.new('az-1', {}),
            Bosh::Director::DeploymentPlan::AvailabilityZone.new('az-2', {})
          ],
          per_spec_logger
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
          per_spec_logger
        )
      end
      let(:vip_network_spec) do
        {
          'name' => 'my-vip-network',
          'type' => 'vip',
        }
      end
      let(:vip_network) { VipNetwork.parse(vip_network_spec, [], per_spec_logger) }
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
        let(:ip) { to_ipaddr('1.1.1.1') }
        let(:ip_provider) { IpProvider.new(ip_repo, networks, per_spec_logger) }

        describe :release do
          context 'when reservation does not have an IP' do
            it 'should raise an error' do
              expect do
                ip_provider.release(ip_reservation)
              end.to raise_error(Bosh::Director::NetworkReservationIpMissing, "Can't release reservation without an IP")
            end

            context 'when reservation is on dynamic network with no IP address' do
              it 'does not fail to release it' do
                dynamic_network = DynamicNetwork.new('my-manual-network', [], nil, per_spec_logger)
                reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, dynamic_network)

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
            let(:dynamic_network) { Bosh::Director::DeploymentPlan::DynamicNetwork.new('fake-dynamic-network', [], nil, per_spec_logger) }
            let(:existing_network_reservation) do
              Bosh::Director::ExistingNetworkReservation.new(
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
              Bosh::Director::ExistingNetworkReservation.new(instance_model, static_vip_network, '69.69.69.69', 'vip')
            end
            let(:static_vip_network) { Bosh::Director::DeploymentPlan::VipNetwork.parse({ 'name' => 'fake-network' }, [], per_spec_logger) }

            it 'saves the ip' do
              ip_provider.reserve_existing_ips(existing_network_reservation)
              expect(existing_network_reservation.static?).to be_truthy
              expect(ip_repo).to have_received(:add).with(existing_network_reservation)
            end
          end

          context 'when manual network' do
            let(:existing_network_reservation) do
              Bosh::Director::ExistingNetworkReservation.new(
                instance_model,
                manual_network,
                '192.168.1.2/32',
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
                  per_spec_logger,
                )
              end

              let(:networks) do
                {
                  'my-manual-network' => manual_network,
                  'my-another-network' => another_manual_network,
                }
              end

              let(:existing_network_reservation) do
                Bosh::Director::ExistingNetworkReservation.new(
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
                  let(:reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, manual_network) }
                  before { reservation.resolve_ip('192.168.2.6') }

                  it 'raises NetworkReservationIpOutsideSubnet' do
                    expect {
                      ip_provider.reserve(reservation)
                    }.to raise_error Bosh::Director::NetworkReservationIpOutsideSubnet
                  end
                end

                context 'when static network reservation' do
                  let(:reservation) { Bosh::Director::DesiredNetworkReservation.new_static(instance_model, manual_network, '192.168.2.6') }

                  it 'raises NetworkReservationIpOutsideSubnet' do
                    expect {
                      ip_provider.reserve(reservation)
                    }.to raise_error Bosh::Director::NetworkReservationIpOutsideSubnet
                  end
                end
              end

              context 'when reservation belongs to subnet' do
                context 'when it is a dynamic reservation' do
                  it 'reserves reservation' do
                    manual_network_spec['subnets'].first['range'] = '192.168.1.0/24'

                    reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, manual_network)

                    reservation.resolve_ip('192.168.1.6')
                    reservation.instance_model.update(availability_zone: 'az-1')

                    ip_provider.reserve(reservation)
                    expect(reservation.ip).to eq(IPAddr.new('192.168.1.6').to_i)
                  end

                  context 'when that IP is now in the reserved range' do
                    before do
                      manual_network_spec['subnets'].first['range'] = '192.168.1.0/24'
                      manual_network_spec['subnets'].first['reserved'] = ['192.168.1.11']
                    end

                    it 'raises an error' do
                      reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, manual_network)
                      reservation.resolve_ip(to_ipaddr('192.168.1.11'))
                      expect do
                        ip_provider.reserve(reservation)
                      end.to raise_error Bosh::Director::NetworkReservationIpReserved,
                                        "Failed to reserve IP '192.168.1.11/32' for network 'my-manual-network': IP belongs to "\
                                        'reserved range'
                    end
                  end

                  context 'when user accidentally includes a static IP in the range' do
                    it 'raises an error' do
                      manual_network_spec['subnets'].first['static'] = ['192.168.1.2']

                      reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, manual_network)
                      reservation.resolve_ip('192.168.1.2')
                      expect {
                        ip_provider.reserve(reservation)
                      }.to raise_error Bosh::Director::NetworkReservationWrongType,
                          "IP '192.168.1.2/32' on network 'my-manual-network' does not belong to dynamic pool"
                    end
                  end
                end

                context 'when it is a static reservation' do
                  before do
                    manual_network_spec['subnets'].first['range'] = '192.168.1.0/24'
                    manual_network_spec['subnets'].first['static'] = ['192.168.1.5']
                  end
                  let(:static_network_reservation) { Bosh::Director::DesiredNetworkReservation.new_static(instance_model, manual_network, '192.168.1.5') }

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
                      reservation = Bosh::Director::DesiredNetworkReservation.new_static(instance_model, manual_network, '192.168.1.11')
                      expect {
                        ip_provider.reserve(reservation)
                      }.to raise_error Bosh::Director::NetworkReservationIpReserved,
                          "Failed to reserve IP '192.168.1.11/32' for network 'my-manual-network': IP belongs to reserved range"
                    end
                  end

                  context 'when user accidentally assigns an IP to a job that is NOT a static IP' do
                    it 'raises an error' do
                      manual_network_spec['subnets'].first['static'] = ['192.168.1.2']
                      reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, manual_network)
                      reservation.resolve_ip('192.168.1.2')
                      expect {
                        ip_provider.reserve(reservation)
                      }.to raise_error Bosh::Director::NetworkReservationWrongType,
                          "IP '192.168.1.2/32' on network 'my-manual-network' does not belong to dynamic pool"
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
                  reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, manual_network)
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
                    }.to raise_error Bosh::Director::NetworkReservationIpReserved, "Failed to reserve IP '192.168.1.6/32' for network 'my-manual-network': IP belongs to reserved range"
                  end
                end
              end
            end

            context 'when IP is not provided' do
              context 'for dynamic reservation' do
                let(:reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, manual_network) }

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
                    }.to raise_error Bosh::Director::NetworkReservationNotEnoughCapacity
                  end
                end

                context 'dynamic_subnet_strategy ordering across subnets' do
                  # az-2 has two candidate subnets: 192.168.2.0/30 and 192.168.3.0/30.
                  let(:subnet_two) { manual_network.subnets.find { |s| s.range.include?(to_ipaddr('192.168.2.1')) } }
                  let(:subnet_three) { manual_network.subnets.find { |s| s.range.include?(to_ipaddr('192.168.3.1')) } }
                  let(:allocated_order) { [] }

                  before do
                    instance_model.update(availability_zone: 'az-2')
                    allow(ip_repo).to receive(:allocate_dynamic_ip) do |_res, subnet|
                      allocated_order << subnet
                      ip
                    end
                  end

                  def seed_dynamic_ip(address)
                    FactoryBot.create(
                      :models_ip_address,
                      network_name: 'my-manual-network',
                      address_str: "#{address}/32",
                      static: false,
                    )
                  end

                  context 'when strategy is first_fit (default)' do
                    before { allow(Config).to receive(:dynamic_subnet_strategy).and_return('first_fit') }

                    it 'fills subnets in manifest order, ignoring existing load' do
                      seed_dynamic_ip('192.168.2.1')
                      seed_dynamic_ip('192.168.2.2')

                      ip_provider.reserve(reservation)

                      expect(allocated_order.first).to eq(subnet_two)
                    end
                  end

                  context 'when strategy is least_loaded' do
                    before { allow(Config).to receive(:dynamic_subnet_strategy).and_return('least_loaded') }

                    it 'with no existing IPs, falls back to manifest order (stable tiebreak)' do
                      ip_provider.reserve(reservation)

                      expect(allocated_order.first).to eq(subnet_two)
                    end

                    it 'tries the least-loaded subnet first' do
                      seed_dynamic_ip('192.168.2.1')
                      seed_dynamic_ip('192.168.2.2')

                      ip_provider.reserve(reservation)

                      expect(allocated_order.first).to eq(subnet_three)
                    end

                    it 'records each allocation so the next VM in the AZ prefers the other subnet' do
                      # allocate_dynamic_ip is stubbed and inserts no DB row, so the shift can only
                      # come from the strategy being notified of the first allocation (record_allocation),
                      # not from a rescan — proves the IpProvider hook fires and the count cache is used.
                      ip_provider.reserve(reservation)

                      second_instance = FactoryBot.create(:models_instance, availability_zone: 'az-2')
                      second_reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(second_instance, manual_network)
                      ip_provider.reserve(second_reservation)

                      expect(allocated_order).to eq([subnet_two, subnet_three])
                    end

                    it 'spills to the next subnet when the least-loaded one is full' do
                      seed_dynamic_ip('192.168.2.1') # subnet_two now loaded => try subnet_three first

                      allow(ip_repo).to receive(:allocate_dynamic_ip) do |_res, subnet|
                        allocated_order << subnet
                        subnet == subnet_three ? nil : ip
                      end

                      ip_provider.reserve(reservation)

                      expect(allocated_order).to eq([subnet_three, subnet_two])
                      expect(reservation.ip).to eq(ip)
                    end

                    it 'is a no-op when only one subnet matches the az' do
                      instance_model.update(availability_zone: 'az-1')

                      ip_provider.reserve(reservation)

                      expect(allocated_order.first).to eq(
                        manual_network.subnets.find { |s| s.range.include?(to_ipaddr('192.168.1.1')) },
                      )
                    end
                  end
                end

                context 'nic_group subnet co-location' do
                  # az-2 has two candidate subnets on distinct IaaS subnets ('aws-2', 'aws-3').
                  # Least-loaded/manifest order (with no load) picks subnet_two first; the
                  # follow-the-leader logic must instead pin to whichever subnet a same-nic_group
                  # sibling was already assigned to.
                  let(:manual_network_spec) do
                    {
                      'name' => 'my-manual-network',
                      'subnets' => [
                        {
                          'range' => '192.168.1.0/30', 'gateway' => '192.168.1.1',
                          'cloud_properties' => { 'subnet' => 'aws-1' }, 'az' => 'az-1',
                        },
                        {
                          'range' => '192.168.2.0/30', 'gateway' => '192.168.2.1',
                          'cloud_properties' => { 'subnet' => 'aws-2' }, 'az' => 'az-2',
                        },
                        {
                          'range' => '192.168.3.0/30', 'gateway' => '192.168.3.1',
                          'cloud_properties' => { 'subnet' => 'aws-3' }, 'azs' => ['az-2'],
                        },
                      ],
                    }
                  end
                  # Sibling network (e.g. the IPv6 ext network) mirrors the same IaaS subnets by
                  # cloud_properties, on different ranges.
                  let(:another_manual_network) do
                    ManualNetwork.parse(
                      {
                        'name' => 'my-another-network',
                        'subnets' => [
                          {
                            'range' => '192.168.12.0/30', 'gateway' => '192.168.12.1',
                            'cloud_properties' => { 'subnet' => 'aws-2' },
                          },
                          {
                            'range' => '192.168.13.0/30', 'gateway' => '192.168.13.1',
                            'cloud_properties' => { 'subnet' => 'aws-3' },
                          },
                        ],
                      },
                      [],
                      per_spec_logger,
                    )
                  end
                  let(:networks) do
                    { 'my-manual-network' => manual_network, 'my-another-network' => another_manual_network }
                  end
                  let(:nic_group) { 7 }
                  let(:reservation) do
                    Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, manual_network, nic_group)
                  end
                  let(:subnet_two) { manual_network.subnets.find { |s| s.range.include?(to_ipaddr('192.168.2.1')) } }
                  let(:subnet_three) { manual_network.subnets.find { |s| s.range.include?(to_ipaddr('192.168.3.1')) } }
                  let(:allocated_order) { [] }

                  before do
                    instance_model.update(availability_zone: 'az-2')
                    allow(Config).to receive(:dynamic_subnet_strategy).and_return('least_loaded')
                    allow(ip_repo).to receive(:allocate_dynamic_ip) do |_res, subnet|
                      allocated_order << subnet
                      ip
                    end
                  end

                  # Seed a same-instance sibling reservation on 'my-another-network', in the
                  # subnet carrying `cloud_props`.
                  def seed_sibling_ip(address, cloud_group)
                    FactoryBot.create(
                      :models_ip_address,
                      instance: instance_model,
                      network_name: 'my-another-network',
                      address_str: "#{address}/32",
                      static: false,
                      nic_group: cloud_group,
                    )
                  end

                  it 'pins the reservation to the subnet a same-nic_group sibling already uses' do
                    # Sibling landed on IaaS subnet 'aws-3' (my-another-network 192.168.13.x).
                    seed_sibling_ip('192.168.13.1', nic_group)

                    ip_provider.reserve(reservation)

                    # Without co-location the empty pools would pick subnet_two (manifest order);
                    # co-location forces subnet_three (matching cloud_properties 'aws-3').
                    expect(allocated_order.first).to eq(subnet_three)
                  end

                  it 'balances freely (leader) when no same-nic_group sibling exists yet' do
                    ip_provider.reserve(reservation)

                    expect(allocated_order.first).to eq(subnet_two)
                  end

                  it 'ignores sibling rows for a different nic_group' do
                    seed_sibling_ip('192.168.13.1', nic_group + 1)

                    ip_provider.reserve(reservation)

                    expect(allocated_order.first).to eq(subnet_two)
                  end

                  it 'does not co-locate when the reservation has no nic_group' do
                    seed_sibling_ip('192.168.13.1', nic_group)
                    reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, manual_network)

                    ip_provider.reserve(reservation)

                    expect(allocated_order.first).to eq(subnet_two)
                  end

                  it 'fails rather than spilling to a different subnet when the pinned subnet is full' do
                    seed_sibling_ip('192.168.13.1', nic_group)
                    allow(ip_repo).to receive(:allocate_dynamic_ip) do |_res, subnet|
                      allocated_order << subnet
                      nil # pinned subnet has no capacity
                    end

                    expect { ip_provider.reserve(reservation) }
                      .to raise_error(Bosh::Director::NetworkReservationNotEnoughCapacity)
                    expect(allocated_order).to eq([subnet_three]) # never tried subnet_two
                  end

                  it 'does not co-locate under the first_fit strategy' do
                    allow(Config).to receive(:dynamic_subnet_strategy).and_return('first_fit')
                    seed_sibling_ip('192.168.13.1', nic_group)

                    ip_provider.reserve(reservation)

                    expect(allocated_order.first).to eq(subnet_two)
                  end

                  context 'when networks is not a name-keyed Hash (as in some specs)' do
                    let(:networks) { [] }

                    it 'falls back to least-loaded ordering without crashing' do
                      seed_sibling_ip('192.168.13.1', nic_group)

                      expect { ip_provider.reserve(reservation) }.not_to raise_error
                      expect(allocated_order.first).to eq(subnet_two)
                    end
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
                  Bosh::Director::ExistingNetworkReservation.new(
                    instance_model,
                    vip_network,
                    '1.1.1.1',
                    'vip',
                  )
                end

                it 'adds the ip address to the ip repository' do
                  ip_provider.reserve(reservation)
                  expect(reservation.ip).to eq('1.1.1.1')
                end
              end

              context 'when a new reservation is needed' do
                let(:reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, vip_network) }

                it 'allocates an ip address for the reservation' do
                  ip_provider.reserve(reservation)
                  expect(reservation.ip).to eq('1.1.1.1')
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
                reservation = Bosh::Director::DesiredNetworkReservation.new_static(instance_model, vip_network, '192.168.1.2')

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
end
