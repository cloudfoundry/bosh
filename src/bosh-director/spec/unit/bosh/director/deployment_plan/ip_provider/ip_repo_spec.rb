require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe IpRepo do
      include IpUtil

      let(:ip_repo) { IpRepo.new(per_spec_logger) }
      let(:instance_model) { FactoryBot.create(:models_instance) }
      let(:network_spec) do
        {
          'name' => 'my-manual-network',
          'subnets' => [
            {
              'range' => '192.168.1.0/29',
              'gateway' => '192.168.1.1',
              'dns' => ['192.168.1.1', '192.168.1.2'],
              'static' => [],
              'reserved' => [],
              'cloud_properties' => {},
              'az' => 'az-1',
            }
          ]
        }
      end
      let(:availability_zones) { [Bosh::Director::DeploymentPlan::AvailabilityZone.new('az-1', {})] }
      let(:network) do
        ManualNetwork.parse(
          network_spec,
          availability_zones,
          per_spec_logger
        )
      end
      let(:subnet) do
        ManualNetworkSubnet.parse(
          network.name,
          network_spec['subnets'].first,
          availability_zones,
        )
      end

      let(:subnet_with_prefix) do
        ManualNetworkSubnet.parse(
          network.name,
          network_spec['subnets'].first.merge('prefix' => '31'),
          availability_zones,
        )
      end

      let(:subnet_with_too_big_prefix) do
        ManualNetworkSubnet.parse(
          network.name,
          network_spec['subnets'].first.merge('prefix' => '30'),
          availability_zones,
        )
      end

      let(:other_network_spec) { network_spec.merge('name' => 'my-other-manual-network') }
      let(:other_network) do
        ManualNetwork.parse(
          other_network_spec,
          availability_zones,
          per_spec_logger
        )
      end
      let(:other_reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, other_network) }
      let(:other_subnet) do
        ManualNetworkSubnet.parse(
          other_network.name,
          other_network_spec['subnets'].first,
          availability_zones,
        )
      end

      before { fake_job }

      def cidr_ip(ip)
        to_ipaddr(ip)
      end

      context :add do
        def dynamic_reservation_with_ip(ip)
          reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network_without_static_pool)
          reservation.resolve_ip(ip)
          ip_repo.add(reservation)

          reservation
        end

        let(:network_without_static_pool) do
          network_spec['subnets'].first['static'] = []
          ManualNetwork.parse(network_spec, availability_zones, per_spec_logger)
        end

        context 'when reservation changes type' do
          context 'from Static to Dynamic' do
            it 'updates type of reservation' do
              network_spec['subnets'].first['static'] = ['192.168.1.5']
              static_reservation = Bosh::Director::DesiredNetworkReservation.new_static(instance_model, network, '192.168.1.5')
              ip_repo.add(static_reservation)

              expect(Bosh::Director::Models::IpAddress.count).to eq(1)
              original_address = Bosh::Director::Models::IpAddress.first
              expect(original_address.static).to eq(true)

              dynamic_reservation = dynamic_reservation_with_ip('192.168.1.5')
              ip_repo.add(dynamic_reservation)

              expect(Bosh::Director::Models::IpAddress.count).to eq(1)
              new_address = Bosh::Director::Models::IpAddress.first
              expect(new_address.static).to eq(false)
              expect(new_address.address_str).to eq(original_address.address_str)
            end
          end

          context 'from Dynamic to Static' do
            it 'update type of reservation' do
              dynamic_reservation = dynamic_reservation_with_ip('192.168.1.5')

              ip_repo.add(dynamic_reservation)

              expect(Bosh::Director::Models::IpAddress.count).to eq(1)
              original_address = Bosh::Director::Models::IpAddress.first
              expect(original_address.static).to eq(false)

              network_spec['subnets'].first['static'] = ['192.168.1.5']
              static_reservation = Bosh::Director::DesiredNetworkReservation.new_static(instance_model, network, '192.168.1.5')
              ip_repo.add(static_reservation)

              expect(Bosh::Director::Models::IpAddress.count).to eq(1)
              new_address = Bosh::Director::Models::IpAddress.first
              expect(new_address.static).to eq(true)
              expect(new_address.address_str).to eq(original_address.address_str)
            end
          end

          context 'from Existing to Static' do
            it 'updates type of reservation' do
              dynamic_reservation = dynamic_reservation_with_ip('192.168.1.5')
              ip_repo.add(dynamic_reservation)

              expect(Bosh::Director::Models::IpAddress.count).to eq(1)
              original_address = Bosh::Director::Models::IpAddress.first
              expect(original_address.static).to eq(false)

              network_spec['subnets'].first['static'] = ['192.168.1.5']
              existing_reservation = Bosh::Director::ExistingNetworkReservation.new(instance_model, network, '192.168.1.5', 'manual')
              ip_repo.add(existing_reservation)

              expect(Bosh::Director::Models::IpAddress.count).to eq(1)
              new_address = Bosh::Director::Models::IpAddress.first
              expect(new_address.static).to eq(true)
              expect(new_address.address_str).to eq(original_address.address_str)
            end
          end
        end

        context 'when reservation changes network' do
          it 'updates network name' do
            network_spec['subnets'].first['static'] = ['192.168.1.5']
            static_reservation = Bosh::Director::DesiredNetworkReservation.new_static(instance_model, network, '192.168.1.5')
            ip_repo.add(static_reservation)

            expect(Bosh::Director::Models::IpAddress.count).to eq(1)
            original_address = Bosh::Director::Models::IpAddress.first
            expect(original_address.static).to eq(true)
            expect(original_address.network_name).to eq(network.name)

            static_reservation_on_another_network = Bosh::Director::DesiredNetworkReservation.new_static(instance_model, other_network, '192.168.1.5')
            ip_repo.add(static_reservation_on_another_network)

            expect(Bosh::Director::Models::IpAddress.count).to eq(1)
            original_address = Bosh::Director::Models::IpAddress.first
            expect(original_address.static).to eq(true)
            expect(original_address.network_name).to eq(other_network.name)
          end
        end

        context 'when IP is released by another deployment' do
          it 'retries to reserve it' do
            allow_any_instance_of(Bosh::Director::Models::IpAddress).to receive(:save) do
              allow_any_instance_of(Bosh::Director::Models::IpAddress).to receive(:save).and_call_original

              raise Sequel::ValidationFailed.new('address and network_name unique')
            end

            network_spec['subnets'].first['static'] = ['192.168.1.5']
            reservation = Bosh::Director::DesiredNetworkReservation.new_static(instance_model, network, '192.168.1.5')
            ip_repo.add(reservation)

            saved_address = Bosh::Director::Models::IpAddress.order(:address_str).last
            expect(saved_address.address_str).to eq(cidr_ip('192.168.1.5').to_s)
            expect(saved_address.network_name).to eq('my-manual-network')
            expect(saved_address.task_id).to eq('fake-task-id')
            expect(saved_address.created_at).to_not be_nil
          end
        end

        context 'when reserving an IP with any previous reservation' do
          it 'should fail if it reserved by a different instance' do
            network_spec['subnets'].first['static'] = ['192.168.1.5']

            other_instance_model = FactoryBot.create(:models_instance, availability_zone: 'az-2')
            original_static_network_reservation = Bosh::Director::DesiredNetworkReservation.new_static(instance_model, network, '192.168.1.5')
            new_static_network_reservation = Bosh::Director::DesiredNetworkReservation.new_static(other_instance_model, network, '192.168.1.5')

            ip_repo.add(original_static_network_reservation)

            expect {
              ip_repo.add(new_static_network_reservation)
            }.to raise_error Bosh::Director::NetworkReservationAlreadyInUse
          end

          it 'should fail if the reserved instance does not exist' do
            network_spec['subnets'].first['static'] = ['192.168.1.5']

            other_instance_model = FactoryBot.create(:models_instance, availability_zone: 'az-2')
            original_static_network_reservation = Bosh::Director::DesiredNetworkReservation.new_static(instance_model, network, '192.168.1.5')
            new_static_network_reservation = Bosh::Director::DesiredNetworkReservation.new_static(other_instance_model, network, '192.168.1.5')

            ip_repo.add(original_static_network_reservation)

            vm = Bosh::Director::Models::OrphanedVm.create(cid: 'some-cid', orphaned_at: Time.now)
            Bosh::Director::Models::IpAddress.first.update(instance_id: nil, orphaned_vm: vm)

            expect do
              ip_repo.add(new_static_network_reservation)
            end.to raise_error Bosh::Director::NetworkReservationAlreadyInUse
          end

          it 'should succeed if it is reserved by the same instance' do
            network_spec['subnets'].first['static'] = ['192.168.1.5']

            static_network_reservation = Bosh::Director::DesiredNetworkReservation.new_static(instance_model, network, '192.168.1.5')

            ip_repo.add(static_network_reservation)

            expect {
              ip_repo.add(static_network_reservation)
            }.not_to raise_error
          end
        end
      end

      describe :allocate_dynamic_ip do
        let(:reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network) }

        context 'when there are no IPs reserved' do
          it 'returns the first in the range' do
            ip_address = ip_repo.allocate_dynamic_ip(reservation, subnet)

            expected_ip_address = cidr_ip('192.168.1.2')
            expect(ip_address).to eq(expected_ip_address)
          end
        end

        it 'reserves IP as dynamic' do
          ip_repo.allocate_dynamic_ip(reservation, subnet)

          saved_address = Bosh::Director::Models::IpAddress.first
          expect(saved_address.static).to eq(false)
        end

        context 'when reserving more than one ip' do
          it 'should reserve the next available address' do
            first = ip_repo.allocate_dynamic_ip(reservation, subnet)
            second = ip_repo.allocate_dynamic_ip(reservation, subnet)
            expect(first).to eq(cidr_ip('192.168.1.2'))
            expect(second).to eq(cidr_ip('192.168.1.3'))
          end
        end

        context 'when there are restricted ips' do
          it 'does not reserve them' do
            network_spec['subnets'].first['reserved'] = ['192.168.1.2', '192.168.1.4']

            expect(ip_repo.allocate_dynamic_ip(reservation, subnet)).to eq(cidr_ip('192.168.1.3'))
            expect(ip_repo.allocate_dynamic_ip(reservation, subnet)).to eq(cidr_ip('192.168.1.5'))
          end
        end

        context 'when existing ips overlap with restricted ips' do
          def save_ip(ip)
            Bosh::Director::Models::IpAddress.new(
              address_str: ip.to_s,
              network_name: 'my-manual-network',
              instance: instance_model,
              task_id: Bosh::Director::Config.current_job.task_id
            ).save
          end

          it 'clears similar ips with smaller prefix' do
            network_spec['subnets'].first['reserved'] = ['192.168.1.0 - 192.168.1.12']
            network_spec['subnets'].first['range'] = '192.168.1.0/24'
            save_ip(cidr_ip('192.168.1.8'))

            ip_address = ip_repo.allocate_dynamic_ip(reservation, subnet)
            expected_ip_address = cidr_ip('192.168.1.13')
            expect(ip_address).to eq(expected_ip_address)
          end
        end

        context 'when there are static and restricted ips' do
          it 'does not reserve them' do
            network_spec['subnets'].first['reserved'] = ['192.168.1.2']
            network_spec['subnets'].first['static'] = ['192.168.1.4']

            expect(ip_repo.allocate_dynamic_ip(reservation, subnet)).to eq(cidr_ip('192.168.1.3'))
            expect(ip_repo.allocate_dynamic_ip(reservation, subnet)).to eq(cidr_ip('192.168.1.5'))
          end
        end

        context 'when there are available IPs between reserved IPs' do
          it 'returns first non-reserved IP' do
            network_spec['subnets'].first['static'] = ['192.168.1.2', '192.168.1.4']

            reservation_1 = Bosh::Director::DesiredNetworkReservation.new_static(instance_model, network, '192.168.1.2')
            reservation_2 = Bosh::Director::DesiredNetworkReservation.new_static(instance_model, network, '192.168.1.4')

            ip_repo.add(reservation_1)
            ip_repo.add(reservation_2)

            reservation_3 = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network)
            ip_address = ip_repo.allocate_dynamic_ip(reservation_3, subnet)

            expect(ip_address).to eq(cidr_ip('192.168.1.3'))
          end
        end

        context 'when all IPs in the range are taken' do
          it 'returns nil' do
            network_spec['subnets'].first['range'] = '192.168.1.0/30'

            ip_repo.allocate_dynamic_ip(reservation, subnet)

            expect(ip_repo.allocate_dynamic_ip(reservation, subnet)).to be_nil
          end
        end

        context 'when there are IPs reserved by other networks with overlapping subnet' do
          it 'returns the next non-reserved IP' do
            ip_address = ip_repo.allocate_dynamic_ip(other_reservation, other_subnet)

            expected_ip_address = cidr_ip('192.168.1.2')
            expect(ip_address).to eq(expected_ip_address)

            ip_address = ip_repo.allocate_dynamic_ip(reservation, subnet)

            expected_ip_address = cidr_ip('192.168.1.3')
            expect(ip_address).to eq(expected_ip_address)
          end
        end

        context 'when a prefix is assigned to the subnet' do
          let(:reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network) }
          it 'reserves the prefix address' do
            ip_address = ip_repo.allocate_dynamic_ip(reservation, subnet_with_prefix)

            expect(ip_address).to eq(cidr_ip('192.168.1.2/31'))
          end

          it 'reserves the next available prefix address' do
            ip_address = ip_repo.allocate_dynamic_ip(other_reservation, other_subnet)

            expected_ip_address = cidr_ip('192.168.1.2')
            expect(ip_address).to eq(expected_ip_address)

            ip_address = ip_repo.allocate_dynamic_ip(reservation, subnet_with_prefix)

            expected_ip_address = cidr_ip('192.168.1.4/31')
            expect(ip_address).to eq(expected_ip_address)

            ip_address = ip_repo.allocate_dynamic_ip(other_reservation, other_subnet)

            expected_ip_address = cidr_ip('192.168.1.3')
            expect(ip_address).to eq(expected_ip_address)

            ip_address = ip_repo.allocate_dynamic_ip(other_reservation, other_subnet)

            expected_ip_address = cidr_ip('192.168.1.6')
            expect(ip_address).to eq(expected_ip_address)
          end

          it 'should stop retrying and return nil if no sufficient range is available' do
            ip_address = ip_repo.allocate_dynamic_ip(other_reservation, other_subnet)

            expected_ip_address = cidr_ip('192.168.1.2')
            expect(ip_address).to eq(expected_ip_address)

            ip_address = ip_repo.allocate_dynamic_ip(reservation, subnet_with_prefix)

            expected_ip_address = cidr_ip('192.168.1.4/31')
            expect(ip_address).to eq(expected_ip_address)

            ip_address = ip_repo.allocate_dynamic_ip(other_reservation, other_subnet)

            expected_ip_address = cidr_ip('192.168.1.3')
            expect(ip_address).to eq(expected_ip_address)

            expect do
              ip_address = ip_repo.allocate_dynamic_ip(other_reservation, subnet_with_prefix)
              expect(ip_address).to be_nil
            end.not_to(change { Bosh::Director::Models::IpAddress.count })
          end

          it 'should stop retrying and return nil if no sufficient range is available' do
            expect do
              ip = ip_repo.allocate_dynamic_ip(reservation, subnet_with_too_big_prefix)
              expect(ip).to be_nil
            end.not_to(change { Bosh::Director::Models::IpAddress.count })
          end
        end

        context 'when reserving IP fails' do
          def fail_saving_ips(ips, fail_error)
            original_saves = {}
            ips.each do |ip|
              ip_address = Bosh::Director::Models::IpAddress.new(
                address_str: ip.to_s,
                network_name: 'my-manual-network',
                instance: instance_model,
                task_id: Bosh::Director::Config.current_job.task_id
              )
              original_save = ip_address.method(:save)
              original_saves[ip.to_s] = original_save
            end

            allow_any_instance_of(Bosh::Director::Models::IpAddress).to receive(:save) do |model|
              if ips.map(&:to_s).include?(model.address_str)
                original_save = original_saves[model.address_str]
                original_save.call
                raise fail_error
              end
              model
            end
          end

          shared_examples :retries_on_race_condition do
            context 'when allocating some IPs fails' do
              before do
                network_spec['subnets'].first['range'] = '192.168.1.0/29'

                fail_saving_ips([
                    cidr_ip('192.168.1.2'),
                    cidr_ip('192.168.1.3'),
                    cidr_ip('192.168.1.4'),
                  ],
                  fail_error
                )
              end

              it 'retries until it succeeds' do
                expect(ip_repo.allocate_dynamic_ip(reservation, subnet)).to eq(cidr_ip('192.168.1.5'))
              end
            end

            context 'when allocating any IP fails' do
              before do
                network_spec['subnets'].first['range'] = '192.168.1.0/29'
                network_spec['subnets'].first['reserved'] = ['192.168.1.5', '192.168.1.6']

                fail_saving_ips([
                    cidr_ip('192.168.1.2'),
                    cidr_ip('192.168.1.3'),
                    cidr_ip('192.168.1.4')
                  ],
                  fail_error
                )
              end

              it 'retries until there are no more IPs available' do
                expect(ip_repo.allocate_dynamic_ip(reservation, subnet)).to be_nil
              end
            end
          end

          context 'when sequel validation errors' do
            let(:fail_error) { Sequel::ValidationFailed.new('address and network are not unique') }

            it_behaves_like :retries_on_race_condition
          end

          context 'when postgres unique errors' do
            let(:fail_error) { Sequel::DatabaseError.new('duplicate key value violates unique constraint') }

            it_behaves_like :retries_on_race_condition
          end

          context 'when mysql unique errors' do
            let(:fail_error) { Sequel::DatabaseError.new('Duplicate entry') }

            it_behaves_like :retries_on_race_condition
          end
        end

        context 'when handling CIDR blocks and overlapping ranges' do
          def save_ip_string(ip_string)
            ip_addr = to_ipaddr(ip_string)
            Bosh::Director::Models::IpAddress.new(
              address_str: ip_addr.to_s,
              network_name: 'my-manual-network',
              instance: instance_model,
              task_id: Bosh::Director::Config.current_job.task_id
            ).save
          end

          context 'when database has individual IPs that are contained in a reserved CIDR block' do
            it 'deduplicates and skips the entire CIDR block' do
              network_spec['subnets'].first['range'] = '10.0.11.32/27'
              network_spec['subnets'].first['gateway'] = '10.0.11.33'
              network_spec['subnets'].first['reserved'] = ['10.0.11.32 - 10.0.11.35', '10.0.11.63']
              network_spec['subnets'].first['static'] = ['10.0.11.36', '10.0.11.37', '10.0.11.38', '10.0.11.39', '10.0.11.40']

              # Simulate database IPs that overlap with reserved range
              save_ip_string('10.0.11.32/32')
              save_ip_string('10.0.11.33/32')

              # Should skip entire /30 block (32-35) and statics (36-40), allocate 41
              ip_address = ip_repo.allocate_dynamic_ip(reservation, subnet)
              expect(ip_address).to eq(cidr_ip('10.0.11.41'))
            end
          end

          context 'when multiple overlapping CIDR blocks exist' do
            it 'deduplicates to largest block only' do
              network_spec['subnets'].first['range'] = '192.168.1.0/24'
              network_spec['subnets'].first['gateway'] = '192.168.1.1'
              network_spec['subnets'].first['reserved'] = [
                '192.168.1.0 - 192.168.1.15',  # /28
                '192.168.1.0 - 192.168.1.3',   # /30
                '192.168.1.4 - 192.168.1.7',   # /30
                '192.168.1.8',                  # /32
              ]

              # Should skip entire /28 block (0-15), allocate 16
              ip_address = ip_repo.allocate_dynamic_ip(reservation, subnet)
              expect(ip_address).to eq(cidr_ip('192.168.1.16'))
            end
          end

          context 'when nested CIDR blocks exist' do
            it 'deduplicates to outermost block' do
              network_spec['subnets'].first['range'] = '192.168.1.0/24'
              network_spec['subnets'].first['gateway'] = '192.168.1.1'
              network_spec['subnets'].first['reserved'] = [
                '192.168.1.0/24',  # Entire range
                '192.168.1.0/26',  # First quarter
                '192.168.1.0/28',  # First 16
              ]

              # Should skip entire /24 block
              ip_address = ip_repo.allocate_dynamic_ip(reservation, subnet)
              expect(ip_address).to be_nil
            end
          end

          context 'when adjacent non-overlapping CIDR blocks exist' do
            it 'preserves all blocks and skips each correctly' do
              network_spec['subnets'].first['range'] = '10.0.0.0/24'
              network_spec['subnets'].first['gateway'] = '10.0.0.1'
              network_spec['subnets'].first['reserved'] = [
                '10.0.0.0 - 10.0.0.3',   # /30 (0-3)
                '10.0.0.4 - 10.0.0.7',   # /30 (4-7)
                '10.0.0.8 - 10.0.0.11',  # /30 (8-11)
              ]

              # Should skip all three /30 blocks, allocate 12
              ip_address = ip_repo.allocate_dynamic_ip(reservation, subnet)
              expect(ip_address).to eq(cidr_ip('10.0.0.12'))
            end
          end

          context 'when large CIDR block contains scattered individual IPs' do
            it 'deduplicates scattered IPs within the block' do
              network_spec['subnets'].first['range'] = '10.1.1.0/24'
              network_spec['subnets'].first['gateway'] = '10.1.1.1'
              network_spec['subnets'].first['reserved'] = ['10.1.1.0/24']
              network_spec['subnets'].first['static'] = []

              # Save individual IPs that are all within the /24
              save_ip_string('10.1.1.5/32')
              save_ip_string('10.1.1.50/32')
              save_ip_string('10.1.1.100/32')
              save_ip_string('10.1.1.200/32')

              # Should skip entire /24, no IPs available
              ip_address = ip_repo.allocate_dynamic_ip(reservation, subnet)
              expect(ip_address).to be_nil
            end
          end

          context 'when handling AWS reserved IP ranges' do
            it 'correctly skips reserved ranges with database IPs' do
              network_spec['subnets'].first['range'] = '10.0.11.32/27'
              network_spec['subnets'].first['gateway'] = '10.0.11.33'
              network_spec['subnets'].first['reserved'] = ['10.0.11.32 - 10.0.11.35', '10.0.11.63']
              network_spec['subnets'].first['static'] = []

              # Simulate AWS reserved range scenario with partial database state
              save_ip_string('10.0.11.32/32')
              save_ip_string('10.0.11.33/32')
              save_ip_string('10.0.11.34/32')

              # Should deduplicate /32s, keep /30, skip entire reserved range (32-35)
              ip_address = ip_repo.allocate_dynamic_ip(reservation, subnet)
              expect(ip_address).to eq(cidr_ip('10.0.11.36'))
            end
          end
        end
      end

      describe :allocate_vip_ip do
        let(:reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network) }

        let(:network) do
          VipNetwork.parse(
            network_spec,
            availability_zones,
            per_spec_logger,
          )
        end

        let(:network_spec) do
          {
            'name' => 'my-vip-network',
            'subnets' => [
              {
                'static' => ['69.69.69.69'],
                'azs' => ['z1'],
              },
            ],
          }
        end

        let(:availability_zones) { [Bosh::Director::DeploymentPlan::AvailabilityZone.new('z1', {})] }

        it 'reserves the next available vip and saves it in the database' do
          expect do
            ip = ip_repo.allocate_vip_ip(reservation, network.subnets.first)
            expect(ip).to eq(cidr_ip('69.69.69.69').base_addr)
          end.to change { Bosh::Director::Models::IpAddress.count }.by(1)

          ip_address = instance_model.ip_addresses.first
          expect(ip_address.address_str).to eq(cidr_ip('69.69.69.69').to_s)
        end

        context 'when there are no vips defined in the network' do
          let(:network_spec) do
            {
              'name' => 'my-vip-network',
              'subnets' => [
                {
                  'static' => [],
                  'azs' => ['z1'],
                },
              ],
            }
          end

          it 'should stop retrying and return nil' do
            expect do
              ip = ip_repo.allocate_vip_ip(reservation, network.subnets.first)
              expect(ip).to be_nil
            end.not_to(change { Bosh::Director::Models::IpAddress.count })

            expect(instance_model.ip_addresses.size).to eq(0)
          end
        end

        context 'when there are no available vips' do
          let(:existing_reservation) { Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network) }

          before do
            ip_repo.allocate_vip_ip(existing_reservation, network.subnets.first)
          end

          it 'should stop retrying and return nil' do
            expect do
              ip = ip_repo.allocate_vip_ip(reservation, network.subnets.first)
              expect(ip).to be_nil
            end.not_to(change { Bosh::Director::Models::IpAddress.count })
          end
        end

        context 'when saving the IP address to the database fails' do
          before do
            response_values = [:raise]
            allow_any_instance_of(Bosh::Director::Models::IpAddress).to receive(:save) do
              v = response_values.shift
              v == :raise ? raise(fail_error) : v
            end
          end

          context 'for a retryable error' do
            let(:fail_error) { Sequel::ValidationFailed.new('address and network are not unique') }

            it 'retries to allocate the vip' do
              ip = ip_repo.allocate_vip_ip(reservation, network.subnets.first)
              expect(ip).to eq(cidr_ip('69.69.69.69').base_addr)
            end
          end

          context 'for any other error' do
            let(:fail_error) { Sequel::DatabaseError.new }

            it 'raises the error' do
              expect do
                ip_repo.allocate_vip_ip(reservation, network.subnets.first)
              end.to raise_error(Sequel::DatabaseError)
            end
          end
        end
      end

      describe :delete do
        before do
          network_spec['subnets'].first['static'] = ['192.168.1.5']

          reservation = Bosh::Director::DesiredNetworkReservation.new_static(instance_model, network, '192.168.1.5')
          ip_repo.add(reservation)
        end

        it 'deletes IP address' do
          expect {
            ip_repo.delete('192.168.1.5/32')
          }.to change {
              Bosh::Director::Models::IpAddress.all.size
            }.by(-1)
        end
      end
    end
end
end
