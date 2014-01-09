# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::DeploymentPlan::VipNetwork do
  before(:each) do
    @deployment_plan = instance_double('Bosh::Director::DeploymentPlan::Planner')
  end

  describe :initialize do
    it "should require cloud properties" do
      lambda {
        BD::DeploymentPlan::VipNetwork.new(@deployment_plan, {
            "name" => "foo"
        })
      }.should raise_error(BD::ValidationMissingField)
    end
  end

  describe :reserve do
    before(:each) do
      @network = BD::DeploymentPlan::VipNetwork.new(@deployment_plan, {
          "name" => "foo",
          "cloud_properties" => {
              "foz" => "baz"
          }
      })
    end

    it "should reserve existing reservations as static" do
      reservation = BD::NetworkReservation.new(
          :ip => "0.0.0.1")
      @network.reserve(reservation)
      reservation.type.should == BD::NetworkReservation::STATIC
      reservation.reserved?.should == true
    end

    it "should fail to reserve dynamic IPs" do
      reservation = BD::NetworkReservation.new(
          :ip => "0.0.0.1", :type => BD::NetworkReservation::DYNAMIC)
      @network.reserve(reservation)
      reservation.reserved?.should == false
      reservation.error.should == BD::NetworkReservation::WRONG_TYPE
    end

    it "should not let you reserve a used IP" do
      reservation = BD::NetworkReservation.new(
          :ip => "0.0.0.1", :type => BD::NetworkReservation::STATIC)
      @network.reserve(reservation)
      reservation.reserved?.should == true
      @network.reserve(reservation)
      reservation.reserved?.should == false
      reservation.error.should == BD::NetworkReservation::USED
    end
  end

  describe :release do
    before(:each) do
      @network = BD::DeploymentPlan::VipNetwork.new(@deployment_plan, {
          "name" => "foo",
          "cloud_properties" => {
              "foz" => "baz"
          }
      })
    end

    it "should release the IP from the used pool" do
      reservation = BD::NetworkReservation.new(
          :ip => "0.0.0.1", :type => BD::NetworkReservation::STATIC)
      @network.reserve(reservation)
      @network.release(reservation)
    end

    it "should fail when there is no IP" do
      reservation = BD::NetworkReservation.new(
          :type => BD::NetworkReservation::DYNAMIC)

      lambda {
        @network.release(reservation)
      }.should raise_error(/without an IP/)
    end
  end

  describe :network_settings do
    before(:each) do
      @network = BD::DeploymentPlan::VipNetwork.new(@deployment_plan, {
          "name" => "foo",
          "cloud_properties" => {
              "foz" => "baz"
          }
      })
    end

    it "should provide the VIP network settings" do
      reservation = BD::NetworkReservation.new(
          :ip => "0.0.0.1", :type => BD::NetworkReservation::STATIC)

      @network.network_settings(reservation, []).should == {
          "type" => "vip",
          "ip" => "0.0.0.1",
          "cloud_properties" => {
              "foz" => "baz"
          }
      }
    end

    it "should fail if there are any defaults" do
      reservation = BD::NetworkReservation.new(
          :ip => "0.0.0.1", :type => BD::NetworkReservation::STATIC)

      lambda {
        @network.network_settings(reservation)
      }.should raise_error(/Can't provide any defaults/)

      lambda {
        @network.network_settings(reservation, nil)
      }.should_not raise_error
    end


  end
end
