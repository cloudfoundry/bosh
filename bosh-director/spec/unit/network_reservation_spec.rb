require 'spec_helper'

module Bosh::Director
  describe 'NetworkReservation' do
    let(:instance) { instance_double(DeploymentPlan::Instance) }
    let(:deployment_plan) { instance_double(DeploymentPlan::Planner, using_global_networking?: true, name: 'fake-deployment') }
    let(:global_network_resolver) { BD::DeploymentPlan::GlobalNetworkResolver.new(deployment_plan) }
    let(:in_memory_ip_repo) {BD::DeploymentPlan::InMemoryIpRepo.new(logger)}
    let(:vip_repo) {BD::DeploymentPlan::VipRepo.new(logger)}
    let(:ip_provider) { BD::DeploymentPlan::IpProviderV2.new(in_memory_ip_repo, vip_repo, false, logger)}
    let(:network_spec) do
      Bosh::Spec::Deployments.network
    end
    let(:network) do
      DeploymentPlan::ManualNetwork.new(
        network_spec,
        [],
        global_network_resolver,
        logger
      )
    end

    describe 'StaticNetworkReservation' do
      let(:reservation) { StaticNetworkReservation.new(instance, network, '192.168.1.10') }

      describe :bind_existing do
        it "should bind to the static reservation if it's valid" do
          other = ExistingNetworkReservation.new(instance, network, '192.168.1.10')
          ip_provider.reserve(other)
          reservation.bind_existing(other)
          expect(reservation.reserved?).to eq(true)
          expect(reservation.ip).to eq(NetAddr::CIDR.create('192.168.1.10'))
        end

        it 'should not take the reservation if it is not unbound' do
          other = DynamicNetworkReservation.new(instance, network)
          allow(other).to receive(:reserved?).and_return(true)
          reservation.bind_existing(other)
          expect(reservation.reserved?).to eq(false)
        end

        it 'should not take the existing reservation if the IP differs' do
          other = ExistingNetworkReservation.new(instance, network, '0.0.0.2')
          allow(other).to receive(:reserved?).and_return(true)
          reservation.bind_existing(other)
          expect(reservation.reserved?).to eq(false)
          expect(reservation.ip).to eq(NetAddr::CIDR.create('192.168.1.10'))
        end

        it 'should not take the reservation if it is not reserved' do
          other = ExistingNetworkReservation.new(instance, network, '192.168.1.10')
          reservation.bind_existing(other)
          expect(reservation.reserved?).to eq(false)
          expect(reservation.ip).to eq(NetAddr::CIDR.create('192.168.1.10'))
        end

        it 'should not take the reservation if it is not in static range' do
          reservation = StaticNetworkReservation.new(instance, network, '192.168.1.2')
          other = ExistingNetworkReservation.new(instance, network, '192.168.1.2')
          ip_provider.reserve(other)
          reservation.bind_existing(other)
          expect(reservation.reserved?).to eq(false)
        end
      end
    end

    describe DynamicNetworkReservation do
      let(:reservation) { DynamicNetworkReservation.new(instance, network) }

      describe '#bind_existing' do
        it 'should bind to the dynamic reservation if it is valid' do
          other = ExistingNetworkReservation.new(instance, network, '192.168.1.2')
          ip_provider.reserve(other)
          reservation.bind_existing(other)
          expect(reservation.reserved?).to eq(true)
          expect(reservation.ip).to eq(NetAddr::CIDR.create('192.168.1.2'))
        end

        it 'should not take the reservation if it is not unbound' do
          other = StaticNetworkReservation.new(instance, network, '0.0.0.1')
          allow(other).to receive(:reserved?).and_return(true)
          reservation.bind_existing(other)
          expect(reservation.reserved?).to eq(false)
        end

        it 'should not take the reservation if it is not reserved' do
          other = ExistingNetworkReservation.new(instance, network, '0.0.0.1')
          reservation.bind_existing(other)
          expect(reservation.reserved?).to eq(false)
          expect(reservation.ip).to eq(nil)
        end
      end
    end
  end
end
