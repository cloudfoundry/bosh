require 'spec_helper'

module Bosh::Director
  describe NetworkReservation do
    let(:instance) { instance_double(DeploymentPlan::Instance) }
    let(:network) { instance_double(DeploymentPlan::Network) }

    describe StaticNetworkReservation do
      let(:reservation) { StaticNetworkReservation.new(instance, network, '0.0.0.1') }

      describe :bind_existing do
        it "should bind to the static reservation if it's valid" do
          other = ExistingNetworkReservation.new(instance, network, '0.0.0.1')
          allow(other).to receive(:reserved?).and_return(true)
          reservation.bind_existing(other)
          expect(reservation.reserved?).to eq(true)
          expect(reservation.ip).to eq(1)
        end

        it 'should not take the reservation if it is not existing' do
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
          expect(reservation.ip).to eq(1)
        end

        it 'should not take the reservation if it is not reserved' do
          other = ExistingNetworkReservation.new(instance, network, '0.0.0.1')
          reservation.bind_existing(other)
          expect(reservation.reserved?).to eq(false)
          expect(reservation.ip).to eq(1)
        end
      end
    end

    describe DynamicNetworkReservation do
      let(:reservation) { DynamicNetworkReservation.new(instance, network) }

      describe :bind_existing do
        it "should bind to the dynamic reservation if it's valid" do
          other = ExistingNetworkReservation.new(instance, network, '0.0.0.1')
          allow(other).to receive(:reserved?).and_return(true)
          reservation.bind_existing(other)
          expect(reservation.reserved?).to eq(true)
          expect(reservation.ip).to eq(1)
        end

        it 'should not take the reservation if it is not existing' do
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

    describe ExistingNetworkReservation do
      let(:reservation) { ExistingNetworkReservation.new(instance, network, '0.0.0.1') }
      describe :reserve do
        it 'reserves on a network' do
          expect(network).to receive(:reserve).with(reservation)
          reservation.reserve
          expect(reservation.reserved?).to eq(true)
        end

        context 'when IP is outside of subnet range' do
          before do
            allow(network).to receive(:reserve).with(reservation).and_raise(NetworkReservationIpOutsideSubnet)
          end

          it 'does not reserve IP' do
            reservation.reserve
            expect(reservation.reserved?).to eq(false)
          end
        end

        context 'when IP is in reserved range' do
          before do
            allow(network).to receive(:reserve).with(reservation).and_raise(NetworkReservationIpReserved)
          end

          it 'does not reserve IP' do
            reservation.reserve
            expect(reservation.reserved?).to eq(false)
          end
        end
      end
    end
  end
end
