# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::NetworkReservation do
  describe :initialize do
    it "should store the IP as an int" do
      reservation = BD::NetworkReservation.new(:ip => "0.0.0.1")
      reservation.ip.should == 1
    end
  end

  describe :take do
    it "should take the dynamic reservation if it's valid" do
      reservation = BD::NetworkReservation.new(
          :type => BD::NetworkReservation::DYNAMIC)
      other = BD::NetworkReservation.new(
          :ip => "0.0.0.1", :type => BD::NetworkReservation::DYNAMIC)
      other.reserved = true
      reservation.take(other)
      reservation.reserved?.should == true
      reservation.ip.should == 1
    end

    it "should take the static reservation if it's valid" do
      reservation = BD::NetworkReservation.new(
          :ip => "0.0.0.1", :type => BD::NetworkReservation::STATIC)
      other = BD::NetworkReservation.new(
          :ip => "0.0.0.1", :type => BD::NetworkReservation::STATIC)
      other.reserved = true
      reservation.take(other)
      reservation.reserved?.should == true
      reservation.ip.should == 1
    end

    it "should not take the reservation if the type differs" do
      reservation = BD::NetworkReservation.new(
          :ip => "0.0.0.1", :type => BD::NetworkReservation::STATIC)
      other = BD::NetworkReservation.new(
          :ip => "0.0.0.1", :type => BD::NetworkReservation::DYNAMIC)
      other.reserved = true
      reservation.take(other)
      reservation.reserved?.should == false
    end

    it "should not take the static reservation if the IP differs" do
      reservation = BD::NetworkReservation.new(
          :ip => "0.0.0.1", :type => BD::NetworkReservation::STATIC)
      other = BD::NetworkReservation.new(
          :ip => "0.0.0.2", :type => BD::NetworkReservation::STATIC)
      other.reserved = true
      reservation.take(other)
      reservation.reserved?.should == false
      reservation.ip.should == 1
    end

    it "should not take the reservation if it wasn't fulfilled" do
      reservation = BD::NetworkReservation.new(
          :type => BD::NetworkReservation::DYNAMIC)
      other = BD::NetworkReservation.new(
          :ip => "0.0.0.1", :type => BD::NetworkReservation::DYNAMIC)
      reservation.take(other)
      reservation.reserved?.should == false
      reservation.ip.should == nil
    end
  end
end
