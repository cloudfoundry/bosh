# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Cloud, "create_vm" do

  def agent_settings(unique_name, network_spec = dynamic_network_spec)
    {
      "vm" => {
        "name" => "vm-#{unique_name}"
      },
      "agent_id" => "agent-id",
      "networks" => { "network_a" => network_spec },
      "disks" => {
        "system" => "/dev/vda",
        "ephemeral" => "/dev/vdb",
        "persistent" => {}
      },
      "env" => {
        "test_env" => "value"
      },
      "foo" => "bar", # Agent env
      "baz" => "zaz"
    }
  end

  def openstack_params(unique_name, user_data, security_groups=[])
    {
      :name => "vm-#{unique_name}",
      :image_ref => "sc-id",
      :flavor_ref => "f-test",
      :key_name => "test_key",
      :security_groups => security_groups,
      :user_data => Yajl::Encoder.encode(user_data),
      :availability_zone => "foobar-1a"
    }
  end

  before(:each) do
    @registry = mock_registry
  end

  it "creates an OpenStack server and polls until it's ready" do
    unique_name = UUIDTools::UUID.random_create.to_s
    user_data = {
      "registry" => {
        "endpoint" => "http://registry:3333"
      },
      "server" => {
        "name" => "vm-#{unique_name}"
      }
    }
    server = double("server", :id => "i-test", :name => "i-test")
    image = double("image", :id => "sc-id", :name => "sc-id")
    flavor = double("flavor", :id => "f-test", :name => "m1.tiny")
    address = double("address", :id => "a-test", :ip => "10.0.0.1",
                     :instance_id => "i-test")

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:create).
          with(openstack_params(unique_name, user_data, %w[default])).
          and_return(server)
      openstack.images.should_receive(:find).and_return(image)
      openstack.flavors.should_receive(:find).and_return(flavor)
      openstack.addresses.should_receive(:each).and_yield(address)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    address.should_receive(:server=).with(nil)
    cloud.should_receive(:wait_resource).with(server, :active, :state)

    @registry.should_receive(:update_settings).
        with("i-test", agent_settings(unique_name))

    vm_id = cloud.create_vm("agent-id", "sc-id",
                            resource_pool_spec,
                            { "network_a" => dynamic_network_spec },
                            nil, { "test_env" => "value" })
    vm_id.should == "i-test"
  end

  it "passes dns servers in server user data when present" do
    unique_name = UUIDTools::UUID.random_create.to_s

    user_data = {
        "registry" => {
          "endpoint" => "http://registry:3333"
        },
        "server" => {
          "name" => "vm-#{unique_name}"
        },
        "dns" => {
          "nameserver" => ["1.2.3.4"]
        }
    }
    server = double("server", :id => "i-test", :name => "i-test")
    image = double("image", :id => "sc-id", :name => "sc-id")
    flavor = double("flavor", :id => "f-test", :name => "m1.tiny")
    address = double("address", :id => "a-test", :ip => "10.0.0.1",
                     :instance_id => "i-test")
    network_spec = dynamic_network_spec
    network_spec["dns"] = ["1.2.3.4"]

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:create).
          with(openstack_params(unique_name, user_data, %w[default])).
          and_return(server)
      openstack.images.should_receive(:find).and_return(image)
      openstack.flavors.should_receive(:find).and_return(flavor)
      openstack.addresses.should_receive(:each).and_yield(address)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    address.should_receive(:server=).with(nil)
    cloud.should_receive(:wait_resource).with(server, :active, :state)

    @registry.should_receive(:update_settings).
        with("i-test", agent_settings(unique_name, network_spec))

    vm_id = cloud.create_vm("agent-id", "sc-id",
                            resource_pool_spec,
                            { "network_a" => network_spec },
                            nil, { "test_env" => "value" })
    vm_id.should == "i-test"
  end


  it "creates an OpenStack server with security group" do
    unique_name = UUIDTools::UUID.random_create.to_s
    user_data = {
      "registry" => {
        "endpoint" => "http://registry:3333"
      },
      "server" => {
        "name" => "vm-#{unique_name}"
      }
    }
    security_groups = %w[bar foo]
    network_spec = dynamic_network_spec
    network_spec["cloud_properties"] = { "security_groups" => security_groups }
    server = double("server", :id => "i-test", :name => "i-test")
    image = double("image", :id => "sc-id", :name => "sc-id")
    flavor = double("flavor", :id => "f-test", :name => "m1.tiny")
    address = double("address", :id => "a-test", :ip => "10.0.0.1",
                     :instance_id => nil)

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:create).
          with(openstack_params(unique_name, user_data, security_groups)).
          and_return(server)
      openstack.images.should_receive(:find).and_return(image)
      openstack.flavors.should_receive(:find).and_return(flavor)
      openstack.addresses.should_receive(:each).and_yield(address)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    cloud.should_receive(:wait_resource).with(server, :active, :state)

    @registry.should_receive(:update_settings).
        with("i-test", agent_settings(unique_name, network_spec))

    vm_id = cloud.create_vm("agent-id", "sc-id",
                            resource_pool_spec,
                            { "network_a" => network_spec },
                            nil, { "test_env" => "value" })
    vm_id.should == "i-test"
  end

  it "associates server with floating ip if vip network is provided" do
    server = double("server", :id => "i-test", :name => "i-test")
    image = double("image", :id => "sc-id", :name => "sc-id")
    flavor = double("flavor", :id => "f-test", :name => "m1.tiny")
    address = double("address", :id => "a-test", :ip => "10.0.0.1",
                     :instance_id => "i-test")

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:create).and_return(server)
      openstack.images.should_receive(:find).and_return(image)
      openstack.flavors.should_receive(:find).and_return(flavor)
      openstack.addresses.should_receive(:find).and_return(address)
    end

    address.should_receive(:server=).with(nil)
    address.should_receive(:server=).with(server)
    cloud.should_receive(:wait_resource).with(server, :active, :state)

    @registry.should_receive(:update_settings)

    vm_id = cloud.create_vm("agent-id", "sc-id",
                            resource_pool_spec,
                            combined_network_spec)
  end

  def volume(zone)
    vol = double("volume")
    vol.stub(:availability_zone).and_return(zone)
    vol
  end

  describe "#select_availability_zone" do
    it "should return nil when all values are nil" do
      cloud = mock_cloud
      cloud.select_availability_zone(nil, nil).should == nil
    end

    it "should select the resource pool availability_zone when disks are nil" do
      cloud = mock_cloud
      cloud.select_availability_zone(nil, "foobar-1a").should == "foobar-1a"
    end

    it "should select the zone from a list of disks" do
      cloud = mock_cloud do |openstack|
        openstack.volumes.stub(:get).and_return(volume("foo"), volume("foo"))
      end
      cloud.select_availability_zone(%w[cid1 cid2], nil).should == "foo"
    end

    it "should select the zone from a list of disks and a default" do
      cloud = mock_cloud do |openstack|
        openstack.volumes.stub(:get).and_return(volume("foo"), volume("foo"))
      end
      cloud.select_availability_zone(%w[cid1 cid2], "foo").should == "foo"
    end
  end

  describe "#ensure_same_availability_zone" do
    it "should raise an error when the zones differ" do
      cloud = mock_cloud
      expect {
        cloud.ensure_same_availability_zone([volume("foo"), volume("bar")],
                                            nil)
      }.to raise_error Bosh::Clouds::CloudError
    end

    it "should raise an error when the zones differ" do
      cloud = mock_cloud
      expect {
        cloud.ensure_same_availability_zone([volume("foo"), volume("bar")],
                                            "foo")
      }.to raise_error Bosh::Clouds::CloudError
    end

    it "should raise an error when the zones differ" do
      cloud = mock_cloud
      expect {
        cloud.ensure_same_availability_zone([volume("foo"), volume("foo")],
                                            "bar")
      }.to raise_error Bosh::Clouds::CloudError
    end
  end

end
