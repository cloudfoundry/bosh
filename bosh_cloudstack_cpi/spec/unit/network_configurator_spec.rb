# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::CloudStackCloud::NetworkConfigurator do

  def set_security_groups(spec, security_groups)
    spec["cloud_properties"] ||= {}
    spec["cloud_properties"]["security_groups"] = security_groups
  end

  def set_network(spec, network_name)
    spec["cloud_properties"] ||= {}
    spec["cloud_properties"]["network_name"] = network_name
  end

  it "should raise an error if the spec isn't a hash" do
    expect {
      Bosh::CloudStackCloud::NetworkConfigurator.new("foo")
    }.to raise_error ArgumentError, /Invalid spec, Hash expected,/
  end

  describe "security groups" do
    it "should be extracted from both dynamic and vip network" do
      spec = {}
      spec["network_a"] = dynamic_network_spec
      set_security_groups(spec["network_a"], %w[foo])
      spec["network_b"] = vip_network_spec
      set_security_groups(spec["network_b"], %w[bar])

      nc = Bosh::CloudStackCloud::NetworkConfigurator.new(spec)
      nc.security_groups(nil).should == %w[bar foo]
    end

    it "should return the default groups if none are extracted" do
      spec = {}
      spec["network_a"] = {"type" => "dynamic"}

      nc = Bosh::CloudStackCloud::NetworkConfigurator.new(spec)
      nc.security_groups(%w[foo]).should == %w[foo]
    end

    it "should return an empty list if no default group is set" do
      spec = {}
      spec["network_a"] = {"type" => "dynamic"}

      nc = Bosh::CloudStackCloud::NetworkConfigurator.new(spec)
      nc.security_groups(nil).should == []
    end

    it "should raise an error when it isn't an array" do
      spec = {}
      spec["network_a"] = dynamic_network_spec
      set_security_groups(spec["network_a"], "foo")

      expect {
        Bosh::CloudStackCloud::NetworkConfigurator.new(spec)
      }.to raise_error ArgumentError, "security groups must be an Array"
    end
  end

  describe "network name" do
    it "should be extracted from dynamic network" do
      spec = {}
      spec["network_a"] = dynamic_network_spec
      set_network(spec["network_a"], "name_a")

      nc = Bosh::CloudStackCloud::NetworkConfigurator.new(spec)
      nc.network_name.should == "name_a"
    end

    it "should not be contained in vip network" do
      spec = {}
      spec["network_a"] = dynamic_network_spec
      spec["network_b"] = vip_network_spec
      set_network(spec["network_b"], "invalid")

      expect {
        nc = Bosh::CloudStackCloud::NetworkConfigurator.new(spec)
      }.to raise_error Bosh::Clouds::CloudError, "Vip network cannot have a network name"
    end
  end

end
