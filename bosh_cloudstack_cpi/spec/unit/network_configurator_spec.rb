# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::NetworkConfigurator do

  def set_security_groups(spec, security_groups)
    spec["cloud_properties"] ||= {}
    spec["cloud_properties"]["security_groups"] = security_groups
  end

  def set_nics(spec, net_id)
    spec["cloud_properties"] ||= {}
    spec["cloud_properties"]["net_id"] = net_id
  end

  it "should raise an error if the spec isn't a hash" do
    expect {
      Bosh::OpenStackCloud::NetworkConfigurator.new("foo")
    }.to raise_error ArgumentError, /Invalid spec, Hash expected,/
  end

  describe "security groups" do
    it "should be extracted from both dynamic and vip network" do
      spec = {}
      spec["network_a"] = dynamic_network_spec
      set_security_groups(spec["network_a"], %w[foo])
      spec["network_b"] = vip_network_spec
      set_security_groups(spec["network_b"], %w[bar])

      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      nc.security_groups(nil).should == %w[bar foo]
    end

    it "should be extracted from both manual and vip network" do
      spec = {}
      spec["network_a"] = manual_network_spec
      set_security_groups(spec["network_a"], %w[foo])
      spec["network_b"] = vip_network_spec
      set_security_groups(spec["network_b"], %w[bar])

      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      nc.security_groups(nil).should == %w[bar foo]
    end

    it "should return the default groups if none are extracted" do
      spec = {}
      spec["network_a"] = {"type" => "dynamic"}

      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      nc.security_groups(%w[foo]).should == %w[foo]
    end

    it "should return an empty list if no default group is set" do
      spec = {}
      spec["network_a"] = {"type" => "dynamic"}

      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      nc.security_groups(nil).should == []
    end

    it "should raise an error when it isn't an array" do
      spec = {}
      spec["network_a"] = dynamic_network_spec
      set_security_groups(spec["network_a"], "foo")

      expect {
        Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      }.to raise_error ArgumentError, "security groups must be an Array"
    end
  end

  describe "private_ip" do
    it "should extract private ip address for manual network" do
      spec = {}
      spec["network_a"] = manual_network_spec
      spec["network_a"]["ip"] = "10.0.0.1"

      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      nc.private_ip.should == "10.0.0.1"
    end

    it "should extract private ip address from manual network when there's also vip network" do
      spec = {}
      spec["network_a"] = vip_network_spec
      spec["network_a"]["ip"] = "10.0.0.1"
      spec["network_b"] = manual_network_spec
      spec["network_b"]["ip"] = "10.0.0.2"      

      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      nc.private_ip.should == "10.0.0.2"
    end     
    
    it "should not extract private ip address for dynamic network" do
      spec = {}
      spec["network_a"] = dynamic_network_spec
      spec["network_a"]["ip"] = "10.0.0.1"

      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      nc.private_ip.should be_nil
    end     
  end

  describe "nics" do
    it "should extract net_id from dynamic network" do
      spec = {}
      spec["network_a"] = dynamic_network_spec
      set_nics(spec["network_a"], "foo")

      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      nc.nics.should == [{ "net_id" => "foo" }]
    end

    it "should extract net_id from manual network" do
      spec = {}
      spec["network_b"] = manual_network_spec
      spec["network_b"]["ip"] = "10.0.0.1"
      set_nics(spec["network_b"], "bar")

      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      nc.nics.should == [{ "net_id" => "bar", "v4_fixed_ip" => "10.0.0.1" }]
    end

    it "should not extract ip address for dynamic network" do
      spec = {}
      spec["network_a"] = dynamic_network_spec
      spec["network_a"]["ip"] = "10.0.0.1"
      set_nics(spec["network_a"], "foo")

      nc = Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      nc.nics.should == [{ "net_id" => "foo" }]
    end

    it "should raise a CloudError if no net_id is extracted for manual networks" do
      spec = {}
      spec["network_b"] = manual_network_spec
      spec["network_b"]["cloud_properties"].delete("net_id")

      expect {
        Bosh::OpenStackCloud::NetworkConfigurator.new(spec)
      }.to raise_error Bosh::Clouds::CloudError, "Manual network must have net_id"
    end
  end
end