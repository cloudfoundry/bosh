require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe NetworkReservationRepository do
      include Bosh::Director::IpUtil

      subject(:network_reservation_repository) { NetworkReservationRepository.new(deployment_plan, logger) }
      let(:existing_instance_model) { Models::Instance.make }
      let(:manual_network_subnet) do
        ManualNetworkSubnet.new(
          'name-7',
          NetAddr::CIDR.create('192.168.1.1/24'),
          nil,
          nil,
          nil,
          nil,
          nil,
          [],
          [],
        )
      end
      let(:network) { BD::DeploymentPlan::ManualNetwork.new('name-7', [manual_network_subnet], logger) }
      let(:deployment_plan) do
        ip_repo = BD::DeploymentPlan::InMemoryIpRepo.new(logger)
        ip_provider = BD::DeploymentPlan::IpProvider.new(ip_repo, {'name-7' => network}, logger)
        instance_double(Planner, network: network, networks: [network], ip_provider: ip_provider)
      end

      context 'when the existing instance model has ip addresses' do
        let(:ip_address) { Models::IpAddress.make(address_str: NetAddr::CIDR.create('192.168.1.1').to_i.to_s) }

        before do
          existing_instance_model.add_ip_address(ip_address)
        end

        it "should return reservations with the model's associated ip address" do
          reservations = network_reservation_repository.fetch_network_reservations(existing_instance_model, {})
          reservation = reservations.find_for_network(network)
          expect(reservation.ip).to eq(ip_address.address)
          expect(reservation.instance_model).to eq(existing_instance_model)
          expect(reservation.network).to eq(network)
        end
      end

      context 'when the existing instance model has no ip addresses, but has instance state for v1 manifests' do
        let(:state) do
          {
            'networks' =>
              {
                'name-7' => {
                  'ip' => '192.168.1.1',
                  'type' => 'dynamic'
                },
              },
          }
        end

        it 'should create new reservation based on the state' do
          expect(Models::IpAddress.all).to be_empty
          reservations = network_reservation_repository.fetch_network_reservations(existing_instance_model, state)
          reservation = reservations.find_for_network(network)
          expect(format_ip(reservation.ip)).to eq('192.168.1.1')
          expect(reservation.instance_model).to eq(existing_instance_model)
          expect(reservation.network).to eq(network)
        end
      end

      context 'when the existing instance model has no ip address and has no instance state' do
        it 'returns an empty reservation' do
          reservations = network_reservation_repository.fetch_network_reservations(existing_instance_model, {})
          expect(reservations.find_for_network(network)).to be_nil
        end
      end
    end
  end
end

