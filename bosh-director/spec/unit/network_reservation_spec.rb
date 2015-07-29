require 'spec_helper'

module Bosh::Director
  describe NetworkReservation do
    let(:instance) { instance_double(DeploymentPlan::Instance) }

    describe :initialize do
      it 'should store the IP as an int' do
        reservation = NetworkReservation.new_static(instance, '0.0.0.1')
        expect(reservation.ip).to eq(1)
      end
    end

    describe :take do
      it "should take the dynamic reservation if it's valid" do
        reservation = NetworkReservation.new_dynamic(instance)
        other = NetworkReservation.new_dynamic(instance)
        other.reserved = true
        reservation.take(other)
        expect(reservation.reserved?).to eq(true)
      end

      it "should take the static reservation if it's valid" do
        reservation = NetworkReservation.new_static(instance, '0.0.0.1')
        other = NetworkReservation.new_static(instance, '0.0.0.1')
        other.reserved = true
        reservation.take(other)
        expect(reservation.reserved?).to eq(true)
        expect(reservation.ip).to eq(1)
      end

      it 'should not take the reservation if the type differs' do
        reservation = NetworkReservation.new_static(instance, '0.0.0.1')
        other = NetworkReservation.new_dynamic(instance)
        other.reserved = true
        reservation.take(other)
        expect(reservation.reserved?).to eq(false)
      end

      it 'should not take the static reservation if the IP differs' do
        reservation = NetworkReservation.new_static(instance, '0.0.0.1')
        other = NetworkReservation.new_static(instance, '0.0.0.2')
        other.reserved = true
        reservation.take(other)
        expect(reservation.reserved?).to eq(false)
        expect(reservation.ip).to eq(1)
      end

      it "should not take the reservation if it wasn't fulfilled" do
        reservation = NetworkReservation.new_dynamic(instance)
        other = NetworkReservation.new_static(instance, '0.0.0.1')
        reservation.take(other)
        expect(reservation.reserved?).to eq(false)
        expect(reservation.ip).to eq(nil)
      end
    end

    describe :handle_error do
      context 'when reservation is static' do
        let(:reservation) { NetworkReservation.new_static(instance, '0.0.0.1') }

        it 'handles already-in-use errors' do
          reservation.error = NetworkReservation::USED

          expect{
            reservation.handle_error('fake-origin')
          }.to raise_error(NetworkReservationAlreadyInUse)
        end

        it 'handles wrong pool type errors' do
          reservation.error = NetworkReservation::WRONG_TYPE

          expect{
            reservation.handle_error('fake-origin')
          }.to raise_error(NetworkReservationWrongType)
        end

        it 'handles other reservation errors' do
          reservation.error = StandardError.new

          expect{
            reservation.handle_error('fake-origin')
          }.to raise_error(NetworkReservationError)
        end
      end

      context 'when reservation is dynamic' do
        let(:reservation) { NetworkReservation.new_dynamic(instance) }

        it 'handles pool capacity errors' do
          reservation.error = NetworkReservation::CAPACITY

          expect{
            reservation.handle_error('fake-origin')
          }.to raise_error(NetworkReservationNotEnoughCapacity)
        end

        it 'handles other reservation errors' do
          reservation.error = StandardError.new

          expect{
            reservation.handle_error('fake-origin')
          }.to raise_error(NetworkReservationError)
        end
      end
    end
  end
end
