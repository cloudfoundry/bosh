require 'spec_helper'

module Bosh::Director
  describe NetworkReservation do
    let(:instance) { instance_double(DeploymentPlan::Instance) }
    let(:network) { instance_double(DeploymentPlan::Network) }

    describe :initialize do
      it 'should store the IP as an int' do
        reservation = StaticNetworkReservation.new(instance, network, '0.0.0.1')
        expect(reservation.ip).to eq(1)
      end
    end

    describe :bind_existing do
      it "should bind to the dynamic reservation if it's valid" do
        reservation = DynamicNetworkReservation.new(instance, network)
        other = ExistingNetworkReservation.new(instance, network, '0.0.0.1')
        allow(other).to receive(:reserved?).and_return(true)
        reservation.bind_existing(other)
        expect(reservation.reserved?).to eq(true)
        expect(reservation.ip).to eq(1)
      end

      it "should bind to the static reservation if it's valid" do
        reservation = StaticNetworkReservation.new(instance, network, '0.0.0.1')
        other = ExistingNetworkReservation.new(instance, network, '0.0.0.1')
        allow(other).to receive(:reserved?).and_return(true)
        reservation.bind_existing(other)
        expect(reservation.reserved?).to eq(true)
        expect(reservation.ip).to eq(1)
      end

      it 'should not take the reservation if it is not existing' do
        reservation = StaticNetworkReservation.new(instance, network, '0.0.0.1')
        other = DynamicNetworkReservation.new(instance, network)
        allow(other).to receive(:reserved?).and_return(true)
        reservation.bind_existing(other)
        expect(reservation.reserved?).to eq(false)
      end

      it 'should not take the existing reservation for static if the IP differs' do
        reservation = StaticNetworkReservation.new(instance, network, '0.0.0.1')
        other = ExistingNetworkReservation.new(instance, network, '0.0.0.2')
        allow(other).to receive(:reserved?).and_return(true)
        reservation.bind_existing(other)
        expect(reservation.reserved?).to eq(false)
        expect(reservation.ip).to eq(1)
      end

      it 'should not take the reservation if it is not reserved' do
        reservation = DynamicNetworkReservation.new(instance, network)
        other = ExistingNetworkReservation.new(instance, network, '0.0.0.1')
        reservation.bind_existing(other)
        expect(reservation.reserved?).to eq(false)
        expect(reservation.ip).to eq(nil)
      end
    end
  end
end
