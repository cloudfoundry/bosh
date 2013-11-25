# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::AwsCloud::NetworkConfigurator do

  let(:dynamic) { {"type" => "dynamic"} }
  let(:manual) { {"type" => "manual", "cloud_properties" => {"subnet" => "sn-xxxxxxxx"}} }
  let(:vip) { {"type" => "vip"} }

  def set_security_groups(spec, security_groups)
    spec["cloud_properties"] = {
        "security_groups" => security_groups
    }
  end

  it "should raise an error if the spec isn't a hash" do
    expect {
      Bosh::AwsCloud::NetworkConfigurator.new("foo")
    }.to raise_error ArgumentError
  end

  describe "#vpc?" do
    it "should be true for a manual network" do
      nc = Bosh::AwsCloud::NetworkConfigurator.new("network1" => manual)
      nc.vpc?.should be(true)
    end

    it "should be false for a dynamic network" do
      nc = Bosh::AwsCloud::NetworkConfigurator.new("network1" => dynamic)
      nc.vpc?.should be(false)
    end

  end

  describe "#private_ip" do
    it "should extract private ip address for manual network" do
      spec = {}
      spec["network_a"] = manual
      spec["network_a"]["ip"] = "10.0.0.1"

      nc = Bosh::AwsCloud::NetworkConfigurator.new(spec)
      nc.private_ip.should == "10.0.0.1"
    end

    it "should extract private ip address from manual network when there's also vip network" do
      spec = {}
      spec["network_a"] = vip
      spec["network_a"]["ip"] = "10.0.0.1"
      spec["network_b"] = manual
      spec["network_b"]["ip"] = "10.0.0.2"      

      nc = Bosh::AwsCloud::NetworkConfigurator.new(spec)
      nc.private_ip.should == "10.0.0.2"
    end     
    
    it "should not extract private ip address for dynamic network" do
      spec = {}
      spec["network_a"] = dynamic
      spec["network_a"]["ip"] = "10.0.0.1"

      nc = Bosh::AwsCloud::NetworkConfigurator.new(spec)
      nc.private_ip.should be_nil
    end     
  end
  
  describe "network types" do

    it "should raise an error if both dynamic and manual networks are defined" do
      network_spec = {
          "network1" => dynamic,
          "network2" => manual
      }
      expect {
        Bosh::AwsCloud::NetworkConfigurator.new(network_spec)
      }.to raise_error Bosh::Clouds::CloudError, "Must have exactly one dynamic or manual network per instance"
    end

    it "should raise an error if neither dynamic nor manual networks are defined" do
      expect {
        Bosh::AwsCloud::NetworkConfigurator.new("network1" => vip)
      }.to raise_error Bosh::Clouds::CloudError, "Exactly one dynamic or manual network must be defined"
    end

    it "should raise an error if multiple vip networks are defined" do
      network_spec = {
          "network1" => vip,
          "network2" => vip
      }
      expect {
        Bosh::AwsCloud::NetworkConfigurator.new(network_spec)
      }.to raise_error Bosh::Clouds::CloudError, "More than one vip network for 'network2'"
    end

    it "should raise an error if multiple dynamic networks are defined" do
      network_spec = {
          "network1" => dynamic,
          "network2" => dynamic
      }
      expect {
        Bosh::AwsCloud::NetworkConfigurator.new(network_spec)
      }.to raise_error Bosh::Clouds::CloudError, "Must have exactly one dynamic or manual network per instance"
    end

    it "should raise an error if multiple manual networks are defined" do
      network_spec = {
          "network1" => manual,
          "network2" => manual
      }
      expect {
        Bosh::AwsCloud::NetworkConfigurator.new(network_spec)
      }.to raise_error Bosh::Clouds::CloudError, "Must have exactly one dynamic or manual network per instance"
    end

    it "should raise an error if an illegal network type is used" do
      expect {
        Bosh::AwsCloud::NetworkConfigurator.new("network1" => {"type" => "foo"})
      }.to raise_error Bosh::Clouds::CloudError, "Invalid network type 'foo' for AWS, " \
                        "can only handle 'dynamic', 'vip', or 'manual' network types"
    end

    describe "#configure" do
      let(:ec2) { double("ec2") }
      let(:instance) { double("instance") }

      describe "with vip" do
        it "should configure dynamic network" do
          network_spec = {"network1" => dynamic, "network2" => vip}
          nc = Bosh::AwsCloud::NetworkConfigurator.new(network_spec)

          nc.vip_network.should_receive(:configure).with(ec2, instance)

          nc.configure(ec2, instance)
        end

        it "should configure manual network" do
          network_spec = {"network1" => vip, "network2" => manual}
          nc = Bosh::AwsCloud::NetworkConfigurator.new(network_spec)

          nc.vip_network.should_receive(:configure).with(ec2, instance)

          nc.configure(ec2, instance)
        end

      end

      describe "without vip" do
        context "without associated elastic ip" do
          it "should configure dynamic network" do
            instance.stub(:elastic_ip).and_return(nil)

            network_spec = {"network1" => dynamic}
            nc = Bosh::AwsCloud::NetworkConfigurator.new(network_spec)

            nc.vip_network.should be_nil

            nc.configure(ec2, instance)
          end

          it "should configure manual network" do
            instance.stub(:elastic_ip).and_return(nil)

            network_spec = {"network1" => manual}
            nc = Bosh::AwsCloud::NetworkConfigurator.new(network_spec)

            nc.vip_network.should be_nil

            nc.configure(ec2, instance)
          end
        end

        context "with previously associated elastic ip" do
          it "should disassociate from the old elastic ip" do
            instance.should_receive(:elastic_ip).and_return(double("elastic ip"))
            instance.should_receive(:id).and_return("i-xxxxxxxx")
            instance.should_receive(:disassociate_elastic_ip)

            network_spec = {"network1" => dynamic}
            nc = Bosh::AwsCloud::NetworkConfigurator.new(network_spec)

            nc.network.stub(:configure)

            nc.configure(ec2, instance)
          end
        end
      end
    end
  end
end
