# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::AwsCloud::Cloud do

  let(:manual) { {"type" => "manual", 
                  "cloud_properties" => {"subnet" => "sn-xxxxxxxx", "security_groups" => %w[default]}} }
  
  before(:each) do
    @registry = mock_registry
  end

  let(:combined_agent_network_spec) do
    {
      'network_a' => dynamic_agent_network_spec,
      'network_b' => vip_network_spec.merge({'use_dhcp' => true})
    }
  end

  let(:dynamic_agent_network_spec) do
    dynamic_network_spec.merge({'use_dhcp' => true})
  end

  it "forces recreation when security groups differ" do
    sec_grp = double("security_group", :name => "newgroup")
    instance = double("instance",
                      :id => "i-foobar",
                      :security_groups => [sec_grp])

    cloud = mock_cloud do |ec2|
      allow(ec2.instances).to receive(:[]).
          with("i-foobar").
          and_return(instance)
    end

    expect {
      cloud.configure_networks("i-foobar", combined_network_spec)
    }.to raise_error Bosh::Clouds::NotSupported
  end

  it "forces recreation when IP address differ" do
    sec_grp = double("security_group", :name => "default")
    instance = double("instance",
                      :id => "i-foobar",
                      :security_groups => [sec_grp],
                      :private_ip_address => "10.10.10.1")

    cloud = mock_cloud do |ec2|
      allow(ec2.instances).to receive(:[]).
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
    allow(Bosh::Clouds::Config).to receive(:task_checkpoint)

    cloud = mock_cloud do |ec2|
      allow(ec2.instances).to receive(:[]).
          with("i-foobar").
          and_return(instance)
      allow(ec2).to receive(:elastic_ips).
          and_return({"10.0.0.1" => "10.0.0.1"})
    end

    old_settings = {"foo" => "bar", "networks" => "baz"}
    new_settings = {"foo" => "bar", "networks" => combined_agent_network_spec}

    expect(@registry).to receive(:read_settings).
        with("i-foobar").
        and_return(old_settings)

    expect(@registry).to receive(:update_settings).with("i-foobar", new_settings)

    expect(instance).to receive(:associate_elastic_ip).with("10.0.0.1")

    cloud.configure_networks("i-foobar", combined_network_spec)
  end

  it "removes elastic ip from the instance if vip network is gone" do
    sec_grp = double("security_group", :name => "default")
    instance = double("instance",
                      :id => "i-foobar",
                      :security_groups => [sec_grp],
                      :private_ip_address => "10.10.10.1")

    cloud = mock_cloud do |ec2|
      allow(ec2.instances).to receive(:[]).
          with("i-foobar").
          and_return(instance)
    end

    expect(instance).to receive(:elastic_ip).and_return("10.0.0.1")
    expect(instance).to receive(:disassociate_elastic_ip)

    old_settings = {"foo" => "bar", "networks" => combined_network_spec}
    new_settings = {
        "foo" => "bar",
        "networks" => {
            "net_a" => dynamic_agent_network_spec
        }
    }

    expect(@registry).to receive(:read_settings).
        with("i-foobar").
        and_return(old_settings)

    expect(@registry).to receive(:update_settings).with("i-foobar", new_settings)

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
        mock_cloud { |ec2| allow(ec2.instances).to receive(:[]).with("i-foobar").and_return(instance) }.
            configure_networks("i-foobar", "net_a" => vip_network_spec)
      }.to raise_error(Bosh::Clouds::CloudError,
                       "Exactly one dynamic or manual network must be defined")
    end

    it "checks that at most one VIP network is defined" do
      expect {
        mock_cloud { |ec2| allow(ec2.instances).to receive(:[]).with("i-foobar").and_return(instance) }.
            configure_networks("i-foobar",
                               "net_a" => vip_network_spec,
                               "net_b" => vip_network_spec)
      }.to raise_error(Bosh::Clouds::CloudError,
                       /More than one vip network/)
    end

    it "checks that at most one dynamic or manual network is defined" do
      allow(instance).to receive(:security_groups).and_return([double("security_group", name: "default")])
      expect {
        mock_cloud { |ec2| allow(ec2.instances).to receive(:[]).with("i-foobar").and_return(instance) }.
            configure_networks("i-foobar",
                               "net_a" => dynamic_network_spec,
                               "net_b" => dynamic_network_spec
        )
      }.to raise_error(Bosh::Clouds::CloudError,
                       "Must have exactly one dynamic or manual network per instance")
    end

    it "checks that the network types are either 'dynamic', 'manual', 'vip', or blank" do
      expect {
        mock_cloud { |ec2| allow(ec2.instances).to receive(:[]).with("i-foobar").and_return(instance) }.
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
