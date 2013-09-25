# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path('../../spec_helper', __FILE__)

module Bosh::Director
  describe NetworkReservation do
    describe :initialize do
      it 'should store the IP as an int' do
        reservation = NetworkReservation.new(ip: '0.0.0.1')
        reservation.ip.should == 1
      end
    end

    describe :take do
      it "should take the dynamic reservation if it's valid" do
        reservation = NetworkReservation.new(type: NetworkReservation::DYNAMIC)
        other = NetworkReservation.new(ip: '0.0.0.1', type: NetworkReservation::DYNAMIC)
        other.reserved = true
        reservation.take(other)
        reservation.reserved?.should == true
        reservation.ip.should == 1
      end

      it "should take the static reservation if it's valid" do
        reservation = NetworkReservation.new(ip: '0.0.0.1', type: NetworkReservation::STATIC)
        other = NetworkReservation.new(ip: '0.0.0.1', type: NetworkReservation::STATIC)
        other.reserved = true
        reservation.take(other)
        reservation.reserved?.should == true
        reservation.ip.should == 1
      end

      it 'should not take the reservation if the type differs' do
        reservation = NetworkReservation.new(ip: '0.0.0.1', type: NetworkReservation::STATIC)
        other = NetworkReservation.new(ip: '0.0.0.1', type: NetworkReservation::DYNAMIC)
        other.reserved = true
        reservation.take(other)
        reservation.reserved?.should == false
      end

      it 'should not take the static reservation if the IP differs' do
        reservation = NetworkReservation.new(ip: '0.0.0.1', type: NetworkReservation::STATIC)
        other = NetworkReservation.new(ip: '0.0.0.2', type: NetworkReservation::STATIC)
        other.reserved = true
        reservation.take(other)
        reservation.reserved?.should == false
        reservation.ip.should == 1
      end

      it "should not take the reservation if it wasn't fulfilled" do
        reservation = NetworkReservation.new(type: NetworkReservation::DYNAMIC)
        other = NetworkReservation.new(ip: '0.0.0.1', type: NetworkReservation::DYNAMIC)
        reservation.take(other)
        reservation.reserved?.should == false
        reservation.ip.should == nil
      end
    end
  end
end
