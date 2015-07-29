require 'spec_helper'

describe Bosh::Director::DeploymentPlan::VipNetwork do
  before { @deployment_plan = instance_double('Bosh::Director::DeploymentPlan::Planner') }
  let(:instance) { instance_double( BD::DeploymentPlan::Instance, model: BD::Models::Instance.make) }

  describe :initialize do
    it "defaults cloud properties to empty hash" do
      network = BD::DeploymentPlan::VipNetwork.new({
          "name" => "foo"
        }, logger)
      expect(network.cloud_properties).to eq({})
    end
  end

  describe :reserve do
    before(:each) do
      @network = BD::DeploymentPlan::VipNetwork.new({
          "name" => "foo",
          "cloud_properties" => {
              "foz" => "baz"
          }
      }, logger)
    end

    it "should reserve existing reservations as static" do
      reservation = BD::NetworkReservation.new_static(instance, "0.0.0.1")
      @network.reserve(reservation)
      expect(reservation.type).to eq(BD::NetworkReservation::STATIC)
      expect(reservation.reserved?).to eq(true)
    end

    it "should fail to reserve dynamic IPs" do
      reservation = BD::NetworkReservation.new_dynamic(instance)
      reservation.ip = "0.0.0.1"
      @network.reserve(reservation)
      expect(reservation.reserved?).to eq(false)
      expect(reservation.error).to eq(BD::NetworkReservation::WRONG_TYPE)
    end

    it "should not let you reserve a used IP" do
      reservation = BD::NetworkReservation.new_static(instance, "0.0.0.1")
      @network.reserve(reservation)
      expect(reservation.reserved?).to eq(true)
      @network.reserve(reservation)
      expect(reservation.reserved?).to eq(false)
      expect(reservation.error).to eq(BD::NetworkReservation::USED)
    end
  end

  describe :release do
    before(:each) do
      @network = BD::DeploymentPlan::VipNetwork.new({
          "name" => "foo",
          "cloud_properties" => {
              "foz" => "baz"
          }
      }, logger)
    end

    it "should release the IP from the used pool" do
      reservation = BD::NetworkReservation.new_static(instance, "0.0.0.1")
      @network.reserve(reservation)
      @network.release(reservation)
    end

    it "should fail when there is no IP" do
      reservation = BD::NetworkReservation.new_dynamic(instance)

      expect {
        @network.release(reservation)
      }.to raise_error(/without an IP/)
    end
  end

  describe :network_settings do
    before(:each) do
      @network = BD::DeploymentPlan::VipNetwork.new({
          "name" => "foo",
          "cloud_properties" => {
              "foz" => "baz"
          }
      }, logger)
    end

    it "should provide the VIP network settings" do
      reservation = BD::NetworkReservation.new_static(instance, "0.0.0.1")

      expect(@network.network_settings(reservation, [])).to eq({
          "type" => "vip",
          "ip" => "0.0.0.1",
          "cloud_properties" => {
              "foz" => "baz"
          }
      })
    end

    it "should fail if there are any defaults" do
      reservation = BD::NetworkReservation.new_static(instance, "0.0.0.1")

      expect {
        @network.network_settings(reservation)
      }.to raise_error(/Can't provide any defaults/)

      expect {
        @network.network_settings(reservation, nil)
      }.not_to raise_error
    end


  end
end
