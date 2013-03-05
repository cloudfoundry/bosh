# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Cloud do

  before(:each) do
    @registry = mock_registry
  end

  it "forces recreation when security groups differ" do
    server = double("server", :id => "i-test", :name => "i-test")
    sec_grp = double("security_group",
                     :body => {"security_groups" => [{"name"=> "newgroup" }]})

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:get).with("i-test").and_return(server)
      openstack.should_receive(:list_security_groups).
          with("i-test").and_return(sec_grp)
    end

    expect {
      cloud.configure_networks("i-test", combined_network_spec)
    }.to raise_error Bosh::Clouds::NotSupported
  end

  it "adds floating ip to the server for vip network" do
    server = double("server", :id => "i-test", :name => "i-test")
    address = double("address", :id => "a-test", :ip => "10.0.0.1",
                     :instance_id => nil)
    sec_grp = double("security_group",
                     :body => {"security_groups" => [{"name"=> "default" }]})

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:get).with("i-test").and_return(server)
      openstack.addresses.should_receive(:find).and_return(address)
      openstack.should_receive(:list_security_groups).
          with("i-test").and_return(sec_grp)
    end

    address.should_receive(:server=).with(server)

    old_settings = { "foo" => "bar", "networks" => "baz" }
    new_settings = { "foo" => "bar", "networks" => combined_network_spec }

    @registry.should_receive(:read_settings).with("i-test").
        and_return(old_settings)
    @registry.should_receive(:update_settings).with("i-test", new_settings)

    cloud.configure_networks("i-test", combined_network_spec)
  end

  it "removes floating ip from the server if vip network is gone" do
    server = double("server", :id => "i-test", :name => "i-test")
    address = double("address", :id => "a-test", :ip => "10.0.0.1",
                     :instance_id => "i-test")
    sec_grp = double("security_group",
                     :body => {"security_groups" => [{"name"=> "default" }]})

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:get).with("i-test").and_return(server)
      openstack.addresses.should_receive(:each).and_yield(address)
      openstack.should_receive(:list_security_groups).
          with("i-test").and_return(sec_grp)
    end

    address.should_receive(:server=).with(nil)

    old_settings = { "foo" => "bar",
                     "networks" => combined_network_spec }
    new_settings = { "foo" => "bar",
                     "networks" => { "net_a" => dynamic_network_spec } }

    @registry.should_receive(:read_settings).with("i-test").
        and_return(old_settings)
    @registry.should_receive(:update_settings).with("i-test", new_settings)

    cloud.configure_networks("i-test", "net_a" => dynamic_network_spec)
  end

  it "performs network sanity check" do
    expect {
      mock_cloud.configure_networks("i-test",
                                    "net_a" => vip_network_spec)
    }.to raise_error(Bosh::Clouds::CloudError,
                     "At least one dynamic network should be defined")

    expect {
      mock_cloud.configure_networks("i-test",
                                    "net_a" => vip_network_spec,
                                    "net_b" => vip_network_spec)
    }.to raise_error(Bosh::Clouds::CloudError, /More than one vip network/)

    expect {
      mock_cloud.configure_networks("i-test",
                                    "net_a" => dynamic_network_spec,
                                    "net_b" => dynamic_network_spec)
    }.to raise_error(Bosh::Clouds::CloudError, /More than one dynamic network/)

    expect {
      mock_cloud.configure_networks("i-test",
                                    "net_a" => { "type" => "foo" })
    }.to raise_error(Bosh::Clouds::CloudError, /Invalid network type `foo'/)
  end

end