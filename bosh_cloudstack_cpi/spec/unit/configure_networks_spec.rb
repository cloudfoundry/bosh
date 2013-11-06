# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::CloudStackCloud::Cloud do

  before(:each) do
    @registry = mock_registry
  end

  it "configures the network when using dynamic network" do
    address = double("address")
    server = double("server", :id => "i-test", :name => "i-test", :addresses => [address])
    security_group = double("security_groups", :name => "default")

    server.should_receive(:security_groups).and_return([security_group])

    cloud = mock_cloud do |compute|
      compute.servers.should_receive(:get).with("i-test").and_return(server)
    end
    cloud.should_receive(:zone_network_type).and_return(:basic)
    address.should_receive(:ip_address).and_return("10.10.10.1")

    network_spec = { "net_a" => dynamic_network_spec }
    old_settings = { "foo" => "bar", "networks" => network_spec }
    new_settings = { "foo" => "bar", "networks" => network_spec }

    @registry.should_receive(:read_settings).with("i-test").and_return(old_settings)
    @registry.should_receive(:update_settings).with("i-test", new_settings)

    cloud.configure_networks("i-test", network_spec)
  end

  it "forces recreation when security groups differ" do
    address = double("address")
    server = double("server", :id => "i-test", :name => "i-test", :addresses => [address])
    security_group = double("security_groups", :name => "newgroups")

    server.should_receive(:security_groups).and_return([security_group])

    cloud = mock_cloud do |compute|
      compute.servers.should_receive(:get).with("i-test").and_return(server)
    end
    cloud.should_receive(:zone_network_type).and_return(:advanced)

    expect {
      cloud.configure_networks("i-test", combined_network_spec)
    }.to raise_error Bosh::Clouds::NotSupported
  end

  it "adds floating ip to the server for vip network" do
    # TODO
  end

  it "removes floating ip from the server if vip network is gone" do
    ## TODO
  end

 def mock_cloud_advanced
   mock_cloud do |compute|
     compute.stub(:zones).and_return(
       [double('foobar-1a',
               :name => mock_cloud_options['cloudstack']['default_zone'],
               :id => 'foobar-1a-id',
               :network_type => 'Advanced')])
   end
 end

 it "performs network sanity check" do
    expect {
      mock_cloud_advanced.configure_networks("i-test",
                                    "net_a" => vip_network_spec)
    }.to raise_error(Bosh::Clouds::CloudError,
                     "At least one dynamic network should be defined")

    expect {
      mock_cloud_advanced.configure_networks("i-test",
                                    "net_a" => vip_network_spec,
                                    "net_b" => vip_network_spec)
    }.to raise_error(Bosh::Clouds::CloudError, /More than one vip network/)

    expect {
      mock_cloud_advanced.configure_networks("i-test",
                                    "net_a" => dynamic_network_spec,
                                    "net_b" => dynamic_network_spec)
    }.to raise_error(Bosh::Clouds::CloudError, /Must have exactly one dynamic network per instance/)

    expect {
      mock_cloud_advanced.configure_networks("i-test",
                                    "net_a" => { "type" => "foo" })
    }.to raise_error(Bosh::Clouds::CloudError, /Invalid network type `foo'/)
  end

end
