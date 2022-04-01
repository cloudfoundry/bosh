require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe IpRepo do
    let(:ip_repo) { IpRepo.new(logger) }
    let(:instance_model) { Bosh::Director::Models::Instance.make }
    let(:network_spec) do
      {
        'name' => 'my-manual-network',
        'subnets' => [
          {
            'range' => 'fdab:d85c:118d:8a46::/125',
            'gateway' => 'fdab:d85c:118d:8a46::1',
            'dns' => ['fdab:d85c:118d:8a46::1', 'fdab:d85c:118d:8a46::2'],
            'static' => [],
            'reserved' => [],
            'cloud_properties' => {},
            'az' => 'az-1',
          },
        ],
      }
    end
    let(:availability_zones) { [BD::DeploymentPlan::AvailabilityZone.new('az-1', {})] }
    let(:network) do
      ManualNetwork.parse(
        network_spec,
        availability_zones,
        logger
      )
    end
    let(:subnet) do
      ManualNetworkSubnet.parse(
        network.name,
        network_spec['subnets'].first,
        availability_zones,
      )
    end

    let(:other_network_spec) { network_spec.merge('name' => 'my-other-manual-network') }
    let(:other_network) do
      ManualNetwork.parse(
        other_network_spec,
        availability_zones,
        logger
      )
    end
    let(:other_reservation) { BD::DesiredNetworkReservation.new_dynamic(instance_model, other_network) }
    let(:other_subnet) do
      ManualNetworkSubnet.parse(
        other_network.name,
        other_network_spec['subnets'].first,
        availability_zones,
      )
    end

    before { fake_job }

    def cidr_ip(ip)
      NetAddr::IPv6.parse(ip).addr
    end

    context :add do
      def dynamic_reservation_with_ip(ip)
        reservation = BD::DesiredNetworkReservation.new_dynamic(instance_model, network_without_static_pool)
        reservation.resolve_ip(ip)
        ip_repo.add(reservation)

        reservation
      end

      let(:network_without_static_pool) do
        network_spec['subnets'].first['static'] = []
        ManualNetwork.parse(network_spec, availability_zones, logger)
      end

      context 'when reservation changes type' do
        context 'from Static to Dynamic' do
          it 'updates type of reservation' do
            network_spec['subnets'].first['static'] = ['fdab:d85c:118d:8a46::5']
            static_reservation = BD::DesiredNetworkReservation.new_static(instance_model, network, 'fdab:d85c:118d:8a46::5')
            ip_repo.add(static_reservation)

            expect(Bosh::Director::Models::IpAddress.count).to eq(1)
            original_address = Bosh::Director::Models::IpAddress.first
            expect(original_address.static).to eq(true)

            dynamic_reservation = dynamic_reservation_with_ip('fdab:d85c:118d:8a46::5')
            ip_repo.add(dynamic_reservation)

            expect(Bosh::Director::Models::IpAddress.count).to eq(1)
            new_address = Bosh::Director::Models::IpAddress.first
            expect(new_address.static).to eq(false)
            expect(new_address.address_str).to eq(original_address.address_str)
          end
        end

        context 'from Dynamic to Static' do
          it 'update type of reservation' do
            dynamic_reservation = dynamic_reservation_with_ip('fdab:d85c:118d:8a46::5')
            ip_repo.add(dynamic_reservation)

            expect(Bosh::Director::Models::IpAddress.count).to eq(1)
            original_address = Bosh::Director::Models::IpAddress.first
            expect(original_address.static).to eq(false)

            network_spec['subnets'].first['static'] = ['fdab:d85c:118d:8a46::5']
            static_reservation = BD::DesiredNetworkReservation.new_static(instance_model, network, 'fdab:d85c:118d:8a46::5')
            ip_repo.add(static_reservation)

            expect(Bosh::Director::Models::IpAddress.count).to eq(1)
            new_address = Bosh::Director::Models::IpAddress.first
            expect(new_address.static).to eq(true)
            expect(new_address.address_str).to eq(original_address.address_str)
          end
        end

        context 'from Existing to Static' do
          it 'updates type of reservation' do
            dynamic_reservation = dynamic_reservation_with_ip('fdab:d85c:118d:8a46::5')
            ip_repo.add(dynamic_reservation)

            expect(Bosh::Director::Models::IpAddress.count).to eq(1)
            original_address = Bosh::Director::Models::IpAddress.first
            expect(original_address.static).to eq(false)

            network_spec['subnets'].first['static'] = ['fdab:d85c:118d:8a46::5']
            existing_reservation = BD::ExistingNetworkReservation.new(instance_model, network, 'fdab:d85c:118d:8a46::5', 'manual')
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
          network_spec['subnets'].first['static'] = ['fdab:d85c:118d:8a46::5']
          static_reservation = BD::DesiredNetworkReservation.new_static(instance_model, network, 'fdab:d85c:118d:8a46::5')
          ip_repo.add(static_reservation)

          expect(Bosh::Director::Models::IpAddress.count).to eq(1)
          original_address = Bosh::Director::Models::IpAddress.first
          expect(original_address.static).to eq(true)
          expect(original_address.network_name).to eq(network.name)

          static_reservation_on_another_network = BD::DesiredNetworkReservation.new_static(instance_model, other_network, 'fdab:d85c:118d:8a46::5')
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

          network_spec['subnets'].first['static'] = ['fdab:d85c:118d:8a46::5']
          reservation = BD::DesiredNetworkReservation.new_static(instance_model, network, 'fdab:d85c:118d:8a46::5')
          ip_repo.add(reservation)

          saved_address = Bosh::Director::Models::IpAddress.order(:address_str).last
          expect(saved_address.address_str).to eq(cidr_ip('fdab:d85c:118d:8a46::5').to_s)
          expect(saved_address.network_name).to eq('my-manual-network')
          expect(saved_address.task_id).to eq('fake-task-id')
          expect(saved_address.created_at).to_not be_nil
        end
      end

      context 'when reserving an IP with any previous reservation' do
        it 'should fail if it reserved by a different instance' do
          network_spec['subnets'].first['static'] = ['fdab:d85c:118d:8a46::5']

          other_instance_model = Bosh::Director::Models::Instance.make(availability_zone: 'az-2')
          original_static_network_reservation = BD::DesiredNetworkReservation.new_static(instance_model, network, 'fdab:d85c:118d:8a46::5')
          new_static_network_reservation = BD::DesiredNetworkReservation.new_static(other_instance_model, network, 'fdab:d85c:118d:8a46::5')

          ip_repo.add(original_static_network_reservation)

          expect {
            ip_repo.add(new_static_network_reservation)
          }.to raise_error BD::NetworkReservationAlreadyInUse
        end

        it 'should succeed if it is reserved by the same instance' do
          network_spec['subnets'].first['static'] = ['fdab:d85c:118d:8a46::5']

          static_network_reservation = BD::DesiredNetworkReservation.new_static(instance_model, network, 'fdab:d85c:118d:8a46::5')

          ip_repo.add(static_network_reservation)

          expect {
            ip_repo.add(static_network_reservation)
          }.not_to raise_error
        end
      end
    end

    describe :allocate_dynamic_ip do
      let(:reservation) { BD::DesiredNetworkReservation.new_dynamic(instance_model, network) }

      context 'when there are no IPs reserved' do
        it 'returns the first in the range' do
          ip_address = ip_repo.allocate_dynamic_ip(reservation, subnet)

          expected_ip_address = cidr_ip('fdab:d85c:118d:8a46::2')
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
          expect(first).to eq(cidr_ip('fdab:d85c:118d:8a46::2'))
          expect(second).to eq(cidr_ip('fdab:d85c:118d:8a46::3'))
        end
      end

      context 'when there are restricted ips' do
        it 'does not reserve them' do
          network_spec['subnets'].first['reserved'] = ['fdab:d85c:118d:8a46::2', 'fdab:d85c:118d:8a46::4']

          expect(ip_repo.allocate_dynamic_ip(reservation, subnet)).to eq(cidr_ip('fdab:d85c:118d:8a46::3'))
          expect(ip_repo.allocate_dynamic_ip(reservation, subnet)).to eq(cidr_ip('fdab:d85c:118d:8a46::5'))
        end
      end

      context 'when there are static and restricted ips' do
        it 'does not reserve them' do
          network_spec['subnets'].first['reserved'] = ['fdab:d85c:118d:8a46::2']
          network_spec['subnets'].first['static'] = ['fdab:d85c:118d:8a46::4']

          expect(ip_repo.allocate_dynamic_ip(reservation, subnet)).to eq(cidr_ip('fdab:d85c:118d:8a46::3'))
          expect(ip_repo.allocate_dynamic_ip(reservation, subnet)).to eq(cidr_ip('fdab:d85c:118d:8a46::5'))
        end
      end

      context 'when there are available IPs between reserved IPs' do
        it 'returns first non-reserved IP' do
          network_spec['subnets'].first['static'] = ['fdab:d85c:118d:8a46::2', 'fdab:d85c:118d:8a46::4']

          reservation_1 = BD::DesiredNetworkReservation.new_static(instance_model, network, 'fdab:d85c:118d:8a46::2')
          reservation_2 = BD::DesiredNetworkReservation.new_static(instance_model, network, 'fdab:d85c:118d:8a46::4')

          ip_repo.add(reservation_1)
          ip_repo.add(reservation_2)

          reservation_3 = BD::DesiredNetworkReservation.new_dynamic(instance_model, network)
          ip_address = ip_repo.allocate_dynamic_ip(reservation_3, subnet)

          expect(ip_address).to eq(cidr_ip('fdab:d85c:118d:8a46::3'))
        end
      end

      context 'when all IPs in the range are taken' do
        it 'returns nil' do
          network_spec['subnets'].first['range'] = 'fdab:d85c:118d:8a46::0/126'

          ip_repo.allocate_dynamic_ip(reservation, subnet)

          expect(ip_repo.allocate_dynamic_ip(reservation, subnet)).to be_nil
        end
      end

      context 'when there are IPs reserved by other networks with overlapping subnet' do
        it 'returns the next non-reserved IP' do
          ip_address = ip_repo.allocate_dynamic_ip(other_reservation, other_subnet)

          expected_ip_address = cidr_ip('fdab:d85c:118d:8a46::2')
          expect(ip_address).to eq(expected_ip_address)

          ip_address = ip_repo.allocate_dynamic_ip(reservation, subnet)

          expected_ip_address = cidr_ip('fdab:d85c:118d:8a46::3')
          expect(ip_address).to eq(expected_ip_address)
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
              network_spec['subnets'].first['range'] = 'fdab:d85c:118d:8a46::0/125'

              fail_saving_ips([
                  cidr_ip('fdab:d85c:118d:8a46::2'),
                  cidr_ip('fdab:d85c:118d:8a46::3'),
                  cidr_ip('fdab:d85c:118d:8a46::4'),
                ],
                fail_error
              )
            end

            it 'retries until it succeeds' do
              expect(ip_repo.allocate_dynamic_ip(reservation, subnet)).to eq(cidr_ip('fdab:d85c:118d:8a46::5'))
            end
          end

          context 'when allocating any IP fails' do
            before do
              network_spec['subnets'].first['range'] = 'fdab:d85c:118d:8a46::0/125'
              network_spec['subnets'].first['reserved'] = ['fdab:d85c:118d:8a46::5', 'fdab:d85c:118d:8a46::6']

              fail_saving_ips([
                  cidr_ip('fdab:d85c:118d:8a46::2'),
                  cidr_ip('fdab:d85c:118d:8a46::3'),
                  cidr_ip('fdab:d85c:118d:8a46::4')
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
    end

    describe :delete do
      before do
        network_spec['subnets'].first['static'] = ['fdab:d85c:118d:8a46::5']

        reservation = BD::DesiredNetworkReservation.new_static(instance_model, network, 'fdab:d85c:118d:8a46::5')
        ip_repo.add(reservation)
      end

      it 'deletes IP address' do
        expect {
          ip_repo.delete('fdab:d85c:118d:8a46::5')
        }.to change {
            Bosh::Director::Models::IpAddress.all.size
          }.by(-1)
      end
    end
  end
end
