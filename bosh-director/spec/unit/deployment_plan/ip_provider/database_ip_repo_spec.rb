require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe DatabaseIpRepo do
    let(:ip_repo) { DatabaseIpRepo.new(logger) }
    let(:instance) { double(:instance, model: Bosh::Director::Models::Instance.make) }
    let(:network_spec) {
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
            'availability_zone' => 'az-1',
          }
        ]
      }
    }
    let(:global_network_resolver) { instance_double(GlobalNetworkResolver, reserved_legacy_ranges: Set.new) }
    let(:ip_provider_factory) { IpProviderFactory.new(logger, global_networking: true) }
    let(:availability_zones) { [BD::DeploymentPlan::AvailabilityZone.new('az-1', {})] }
    let(:network) do
      ManualNetwork.new(
        network_spec,
        availability_zones,
        global_network_resolver,
        ip_provider_factory,
        logger
      )
    end

    before do
      Bosh::Director::Config.current_job = Bosh::Director::Jobs::BaseJob.new
      Bosh::Director::Config.current_job.task_id = 'fake-task-id'
    end

    def cidr_ip(ip)
      NetAddr::CIDR.create(ip).to_i
    end

    context :add do
      def dynamic_reservation_bound_to_existing_with_ip(ip)
        network_spec['subnets'].first['static'] = []
        other_network = ManualNetwork.new(network_spec, availability_zones, global_network_resolver, ip_provider_factory, logger)

        dynamic_reservation = BD::DynamicNetworkReservation.new(instance, other_network)

        network_spec['subnets'].first['static'] = ['192.168.1.5']
        existing_reservation = BD::ExistingNetworkReservation.new(instance, network, ip)
        existing_reservation.mark_reserved_as(BD::DynamicNetworkReservation)
        dynamic_reservation.bind_existing(existing_reservation)

        dynamic_reservation
      end

      context 'when reservation changes type' do
        context 'from Static to Dynamic' do
          it 'updates type of reservation' do
            network_spec['subnets'].first['static'] = ['192.168.1.5']
            static_reservation = BD::StaticNetworkReservation.new(instance, network, '192.168.1.5')
            ip_repo.add(static_reservation)

            expect(Bosh::Director::Models::IpAddress.count).to eq(1)
            original_address = Bosh::Director::Models::IpAddress.first
            expect(original_address.static).to eq(true)

            dynamic_reservation = dynamic_reservation_bound_to_existing_with_ip('192.168.1.5')
            ip_repo.add(dynamic_reservation)

            expect(Bosh::Director::Models::IpAddress.count).to eq(1)
            new_address = Bosh::Director::Models::IpAddress.first
            expect(new_address.static).to eq(false)
            expect(new_address.address).to eq(original_address.address)
          end
        end

        context 'from Dynamic to Static' do
          it 'update type of reservation' do
            dynamic_reservation = dynamic_reservation_bound_to_existing_with_ip('192.168.1.5')
            ip_repo.add(dynamic_reservation)

            expect(Bosh::Director::Models::IpAddress.count).to eq(1)
            original_address = Bosh::Director::Models::IpAddress.first
            expect(original_address.static).to eq(false)

            static_reservation = BD::StaticNetworkReservation.new(instance, network, '192.168.1.5')
            ip_repo.add(static_reservation)

            expect(Bosh::Director::Models::IpAddress.count).to eq(1)
            new_address = Bosh::Director::Models::IpAddress.first
            expect(new_address.static).to eq(true)
            expect(new_address.address).to eq(original_address.address)
          end
        end

        context 'from Existing to Static' do
          it 'updates type of reservation' do
            dynamic_reservation = dynamic_reservation_bound_to_existing_with_ip('192.168.1.5')
            ip_repo.add(dynamic_reservation)

            expect(Bosh::Director::Models::IpAddress.count).to eq(1)
            original_address = Bosh::Director::Models::IpAddress.first
            expect(original_address.static).to eq(false)

            existing_reservation = BD::ExistingNetworkReservation.new(instance, network, '192.168.1.5')
            ip_repo.add(existing_reservation)

            expect(Bosh::Director::Models::IpAddress.count).to eq(1)
            new_address = Bosh::Director::Models::IpAddress.first
            expect(new_address.static).to eq(true)
            expect(new_address.address).to eq(original_address.address)
          end
        end
      end

      context 'when IP is released by another deployment' do
        it 'retries to reserve it' do
          allow_any_instance_of(Bosh::Director::Models::IpAddress).to receive(:save) do
            allow_any_instance_of(Bosh::Director::Models::IpAddress).to receive(:save).and_call_original

            raise Sequel::ValidationFailed.new('address and network_name unique')
          end

          network_spec['subnets'].first['static'] = ['192.168.1.5']
          reservation = BD::StaticNetworkReservation.new(instance, network, '192.168.1.5')
          ip_repo.add(reservation)

          saved_address = Bosh::Director::Models::IpAddress.order(:address).last
          expect(saved_address.address).to eq(cidr_ip('192.168.1.5'))
          expect(saved_address.network_name).to eq('my-manual-network')
          expect(saved_address.task_id).to eq('fake-task-id')
          expect(saved_address.created_at).to_not be_nil
        end
      end

      context 'when reserving an IP with any previous reservation' do
        it 'should fail if it reserved by a different instance' do
          network_spec['subnets'].first['static'] = ['192.168.1.5']

          other_instance = double(:instance, model: Bosh::Director::Models::Instance.make, availability_zone: BD::DeploymentPlan::AvailabilityZone.new('az-2', {}))
          original_static_network_reservation = BD::StaticNetworkReservation.new(instance, network, '192.168.1.5')
          new_static_network_reservation = BD::StaticNetworkReservation.new(other_instance, network, '192.168.1.5')

          ip_repo.add(original_static_network_reservation)

          expect {
            ip_repo.add(new_static_network_reservation)
          }.to raise_error BD::NetworkReservationAlreadyInUse
        end

        it 'should succeed if it is reserved by the same instance' do
          network_spec['subnets'].first['static'] = ['192.168.1.5']

          static_network_reservation = BD::StaticNetworkReservation.new(instance, network, '192.168.1.5')

          ip_repo.add(static_network_reservation)

          expect {
            ip_repo.add(static_network_reservation)
          }.not_to raise_error
        end
      end
    end
  end
end
