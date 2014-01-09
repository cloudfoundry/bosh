# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::DeploymentPlan::DynamicNetwork do
  before(:each) do
    @deployment_plan = instance_double('Bosh::Director::DeploymentPlan::Planner')
  end

  describe :initialize do
    it "should parse spec" do
      network = BD::DeploymentPlan::DynamicNetwork.new(@deployment_plan, {
          "name" => "foo",
          "cloud_properties" => {
              "foz" => "baz"
          }
      })
      network.cloud_properties.should == {"foz" => "baz"}
    end

    it "should require cloud properties" do
      lambda {
        BD::DeploymentPlan::DynamicNetwork.new(@deployment_plan, {
            "name" => "foo"
        })
      }.should raise_error(BD::ValidationMissingField)
    end

    it "should parse dns servers" do
      network = BD::DeploymentPlan::DynamicNetwork.new(@deployment_plan, {
          "name" => "foo",
          "dns" => %w[1.2.3.4 5.6.7.8],
          "cloud_properties" => {
              "foz" => "baz"
          }
      })
      network.dns.should == %w[1.2.3.4 5.6.7.8]
    end
  end

  describe :reserve do
    before(:each) do
      @network = BD::DeploymentPlan::DynamicNetwork.new(@deployment_plan, {
          "name" => "foo",
          "cloud_properties" => {
              "foz" => "baz"
          }
      })
    end

    it "should reserve an existing IP" do
      reservation = BD::NetworkReservation.new(
          :ip => "0.0.0.1", :type => BD::NetworkReservation::DYNAMIC)
      @network.reserve(reservation)
      reservation.reserved?.should == true
      reservation.ip.should == 4294967295
    end

    it "should not let you reserve a static IP" do
      reservation = BD::NetworkReservation.new(
          :ip => "0.0.0.1", :type => BD::NetworkReservation::STATIC)
      @network.reserve(reservation)
      reservation.reserved?.should == false
      reservation.error.should == BD::NetworkReservation::WRONG_TYPE
    end
  end

  describe :release do
    before(:each) do
      @network = BD::DeploymentPlan::DynamicNetwork.new(@deployment_plan, {
          "name" => "foo",
          "cloud_properties" => {
              "foz" => "baz"
          }
      })
    end

    it "should release the IP from the subnet" do
      reservation = BD::NetworkReservation.new(
          :ip => 4294967295, :type => BD::NetworkReservation::DYNAMIC)

      @network.release(reservation)
    end

    it "should fail when the IP doesn't match the magic dynamic IP" do
      reservation = BD::NetworkReservation.new(
          :ip => 1, :type => BD::NetworkReservation::DYNAMIC)

      lambda {
        @network.release(reservation)
      }.should raise_error(/magic DYNAMIC IP/)
    end
  end

  describe :network_settings do
    before(:each) do
      @network = BD::DeploymentPlan::DynamicNetwork.new(@deployment_plan, {
          "name" => "foo",
          "cloud_properties" => {
              "foz" => "baz"
          }
      })
    end

    it "should provide dynamic network settings" do
      reservation = BD::NetworkReservation.new(
          :ip => 4294967295, :type => BD::NetworkReservation::DYNAMIC)
      @network.network_settings(reservation, []).should == {
          "type" => "dynamic",
          "cloud_properties" => {"foz" => "baz"},
          "default" => []
      }
    end

    it "should set the defaults" do
      reservation = BD::NetworkReservation.new(
          :ip => 4294967295, :type => BD::NetworkReservation::DYNAMIC)
      @network.network_settings(reservation).should == {
          "type" => "dynamic",
          "cloud_properties" => {"foz" => "baz"},
          "default" => ["dns", "gateway"]
      }
    end

    it "should fail when the IP doesn't match the magic dynamic IP" do
      reservation = BD::NetworkReservation.new(
          :ip => 1, :type => BD::NetworkReservation::DYNAMIC)
      lambda {
        @network.network_settings(reservation)
      }.should raise_error(/magic DYNAMIC IP/)
    end
  end
end
