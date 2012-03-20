# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AwsCloud::Cloud do

  before(:each) do
    @registry = mock_registry
  end

  it "adds elastic ip from to the instance for vip network" do
    instance = double("instance",
                      :id => "i-foobar")

    cloud = mock_cloud do |ec2|
      ec2.instances.stub(:[]).
        with("i-foobar").
        and_return(instance)
    end

    old_settings = { "foo" => "bar", "networks" => "baz" }
    new_settings = { "foo" => "bar", "networks" => combined_network_spec }

    @registry.should_receive(:read_settings).
      with("i-foobar").
      and_return(old_settings)

    @registry.should_receive(:update_settings).with("i-foobar", new_settings)

    instance.should_receive(:associate_elastic_ip).with("10.0.0.1")

    cloud.configure_networks("i-foobar", combined_network_spec)
  end

  it "removes elastic ip from the instance if vip network is gone" do
    instance = double("instance",
                      :id => "i-foobar")

    cloud = mock_cloud do |ec2|
      ec2.instances.stub(:[]).
        with("i-foobar").
        and_return(instance)
    end

    instance.should_receive(:elastic_ip).and_return("10.0.0.1")
    instance.should_receive(:disassociate_elastic_ip)

    old_settings = { "foo" => "bar", "networks" => combined_network_spec }
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

  it "performs network sanity check" do
    expect {
      mock_cloud.configure_networks("i-foobar", "net_a" => vip_network_spec)
    }.to raise_error(Bosh::Clouds::CloudError,
                     "At least one dynamic network should be defined")

    expect {
      mock_cloud.configure_networks("i-foobar",
                                    "net_a" => vip_network_spec,
                                    "net_b" => vip_network_spec)
    }.to raise_error(Bosh::Clouds::CloudError,
                     /More than one vip network/)

    expect {
      mock_cloud.configure_networks("i-foobar",
                                    "net_a" => dynamic_network_spec,
                                    "net_b" => dynamic_network_spec)
    }.to raise_error(Bosh::Clouds::CloudError,
                     /More than one dynamic network/)

    expect {
      mock_cloud.configure_networks("i-foobar",
                                    "net_a" => { "type" => "foo" })
    }.to raise_error(Bosh::Clouds::CloudError,
                     /Invalid network type `foo'/)
  end

end
