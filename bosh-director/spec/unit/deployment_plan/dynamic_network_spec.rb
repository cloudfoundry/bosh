require 'spec_helper'

describe Bosh::Director::DeploymentPlan::DynamicNetwork do
  before(:each) do
    @deployment_plan = instance_double('Bosh::Director::DeploymentPlan::Planner')
  end

  let(:logger) { Logging::Logger.new('TestLogger') }
  let(:instance) { instance_double(Bosh::Director::DeploymentPlan::Instance) }

  describe :initialize do
    it "should parse spec" do
      network = BD::DeploymentPlan::DynamicNetwork.new({
          "name" => "foo",
          "cloud_properties" => {
              "foz" => "baz"
          }
      }, logger)
      expect(network.cloud_properties).to eq({"foz" => "baz"})
    end

    it "defaults cloud properties to empty hash" do
      network = BD::DeploymentPlan::DynamicNetwork.new({
          "name" => "foo",
        }, logger)
      expect(network.cloud_properties).to eq({})
    end

    it "should parse dns servers" do
      network = BD::DeploymentPlan::DynamicNetwork.new({
          "name" => "foo",
          "dns" => %w[1.2.3.4 5.6.7.8],
          "cloud_properties" => {
              "foz" => "baz"
          }
      }, logger)
      expect(network.dns).to eq(%w[1.2.3.4 5.6.7.8])
    end
  end

  describe :reserve do
    before(:each) do
      @network = BD::DeploymentPlan::DynamicNetwork.new({
          "name" => "foo",
          "cloud_properties" => {
              "foz" => "baz"
          }
      }, logger)
    end

    it "should reserve an existing IP" do
      reservation = BD::NetworkReservation.new_dynamic(instance, @network)
      reservation.ip = '0.0.0.1'
      @network.reserve(reservation)
      expect(reservation.reserved?).to eq(true)
      expect(reservation.ip).to eq(4294967295)
    end

    it "should not let you reserve a static IP" do
      reservation = BD::NetworkReservation.new_static(instance, @network, '0.0.0.1')

      expect {
        @network.reserve(reservation)
      }.to raise_error BD::NetworkReservationWrongType
    end
  end

  describe :release do
    before(:each) do
      @network = BD::DeploymentPlan::DynamicNetwork.new({
          "name" => "foo",
          "cloud_properties" => {
              "foz" => "baz"
          }
      }, logger)
    end

    it "should release the IP from the subnet" do
      reservation = BD::NetworkReservation.new_dynamic(instance, @network)
      reservation.ip = 4294967295

      @network.release(reservation)
    end

    it "should fail when the IP doesn't match the magic dynamic IP" do
      reservation = BD::NetworkReservation.new_dynamic(instance, @network)
      reservation.ip = 1

      expect {
        @network.release(reservation)
      }.to raise_error(/magic DYNAMIC IP/)
    end
  end

  describe :network_settings do
    before(:each) do
      @network = BD::DeploymentPlan::DynamicNetwork.new({
          "name" => "foo",
          "cloud_properties" => {
              "foz" => "baz"
          }
      }, logger)
    end

    it "should provide dynamic network settings" do
      reservation = BD::NetworkReservation.new_dynamic(instance, @network)
      reservation.ip = 4294967295
      expect(@network.network_settings(reservation, [])).to eq({
          "type" => "dynamic",
          "cloud_properties" => {"foz" => "baz"},
          "default" => []
      })
    end

    it "should set the defaults" do
      reservation = BD::NetworkReservation.new_dynamic(instance, @network)
      reservation.ip = 4294967295
      expect(@network.network_settings(reservation)).to eq({
          "type" => "dynamic",
          "cloud_properties" => {"foz" => "baz"},
          "default" => ["dns", "gateway"]
      })
    end

    it "should fail when the IP doesn't match the magic dynamic IP" do
      reservation = BD::NetworkReservation.new_dynamic(instance, @network)
      reservation.ip = 1
      expect {
        @network.network_settings(reservation)
      }.to raise_error(/magic DYNAMIC IP/)
    end
  end
end
