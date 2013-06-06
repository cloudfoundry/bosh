# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::AwsCloud::Cloud do

  let(:manual) { {"type" => "manual", 
                  "cloud_properties" => {"subnet" => "sn-xxxxxxxx", "security_groups" => %w[default]}} }
  
  before(:each) do
    @registry = mock_registry
  end

  it "forces recreation when security groups differ" do
    sec_grp = double("security_group", :name => "newgroup")
    instance = double("instance",
                      :id => "i-foobar",
                      :security_groups => [sec_grp])

    cloud = mock_cloud do |ec2|
      ec2.instances.stub(:[]).
          with("i-foobar").
          and_return(instance)
    end

    lambda {
      cloud.configure_networks("i-foobar", combined_network_spec)
    }.should raise_error Bosh::Clouds::NotSupported
  end

  it "forces recreation when IP address differ" do
    sec_grp = double("security_group", :name => "default")
    instance = double("instance",
                      :id => "i-foobar",
                      :security_groups => [sec_grp],
                      :private_ip_address => "10.10.10.1")

    cloud = mock_cloud do |ec2|
      ec2.instances.stub(:[]).
          with("i-foobar").
          and_return(instance)
    end

    network_spec = { "net_a" => manual }
    network_spec["net_a"]["ip"] = "10.10.10.2"
    expect {
      cloud.configure_networks("i-foobar", network_spec)
    }.to raise_error(Bosh::Clouds::NotSupported, "IP address change requires VM recreation: 10.10.10.1 to 10.10.10.2")
  end  
  
  it "adds elastic ip from to the instance for vip network" do
    sec_grp = double("security_group", :name => "default")
    instance = double("instance",
                      :id => "i-foobar",
                      :security_groups => [sec_grp],
                      :private_ip_address => "10.10.10.1")
    Bosh::Clouds::Config.stub(:task_checkpoint)

    cloud = mock_cloud do |ec2|
      ec2.instances.stub(:[]).
          with("i-foobar").
          and_return(instance)
      ec2.stub(:elastic_ips).
          and_return({"10.0.0.1" => "10.0.0.1"})
    end

    old_settings = {"foo" => "bar", "networks" => "baz"}
    new_settings = {"foo" => "bar", "networks" => combined_network_spec}

    @registry.should_receive(:read_settings).
        with("i-foobar").
        and_return(old_settings)

    @registry.should_receive(:update_settings).with("i-foobar", new_settings)

    instance.should_receive(:associate_elastic_ip).with("10.0.0.1")

    cloud.configure_networks("i-foobar", combined_network_spec)
  end

  it "removes elastic ip from the instance if vip network is gone" do
    sec_grp = double("security_group", :name => "default")
    instance = double("instance",
                      :id => "i-foobar",
                      :security_groups => [sec_grp],
                      :private_ip_address => "10.10.10.1")

    cloud = mock_cloud do |ec2|
      ec2.instances.stub(:[]).
          with("i-foobar").
          and_return(instance)
    end

    instance.should_receive(:elastic_ip).and_return("10.0.0.1")
    instance.should_receive(:disassociate_elastic_ip)

    old_settings = {"foo" => "bar", "networks" => combined_network_spec}
    new_settings = {
        "foo" => "bar",
        "networks" => {
            "net_a" => dynamic_network_spec
        }
    }

    @registry.should_receive(:read_settings).
        with("i-foobar").
        and_return(old_settings)

    @registry.should_receive(:update_settings).with("i-foobar", new_settings)

    cloud.configure_networks("i-foobar", "net_a" => dynamic_network_spec)
  end

  describe "performs network sanity check" do
    let(:instance) do
      instance = double("instance",
                        :id => "i-foobar",
                        :security_groups => [])
    end

    it "checks that at least one dynamic or manual network is defined" do
      expect {
        mock_cloud { |ec2| ec2.instances.stub(:[]).with("i-foobar").and_return(instance) }.
            configure_networks("i-foobar", "net_a" => vip_network_spec)
      }.to raise_error(Bosh::Clouds::CloudError,
                       "Exactly one dynamic or manual network must be defined")
    end

    it "checks that at most one VIP network is defined" do
      expect {
        mock_cloud { |ec2| ec2.instances.stub(:[]).with("i-foobar").and_return(instance) }.
            configure_networks("i-foobar",
                               "net_a" => vip_network_spec,
                               "net_b" => vip_network_spec)
      }.to raise_error(Bosh::Clouds::CloudError,
                       /More than one vip network/)
    end

    it "checks that at most one dynamic or manual network is defined" do
      instance.stub(:security_groups).and_return([double("security_group", name: "default")])
      expect {
        mock_cloud { |ec2| ec2.instances.stub(:[]).with("i-foobar").and_return(instance) }.
            configure_networks("i-foobar",
                               "net_a" => dynamic_network_spec,
                               "net_b" => dynamic_network_spec
        )
      }.to raise_error(Bosh::Clouds::CloudError,
                       "Must have exactly one dynamic or manual network per instance")
    end

    it "checks that the network types are either 'dynamic', 'manual', 'vip', or blank" do
      expect {
        mock_cloud { |ec2| ec2.instances.stub(:[]).with("i-foobar").and_return(instance) }.
            configure_networks("i-foobar",
                               "net_a" => {
                                   "type" => "foo",
                                   "cloud_properties" => {"security_groups" => []}
                               })
      }.to raise_error(Bosh::Clouds::CloudError,
                       /Invalid network type 'foo'/)
    end
  end
end
