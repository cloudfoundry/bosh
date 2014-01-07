# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Cloud, "create_vm" do

  def agent_settings(unique_name, network_spec = dynamic_network_spec, ephemeral = "/dev/sdb")
    {
      "vm" => {
        "name" => "vm-#{unique_name}"
      },
      "agent_id" => "agent-id",
      "networks" => { "network_a" => network_spec },
      "disks" => {
        "system" => "/dev/sda",
        "ephemeral" => ephemeral,
        "persistent" => {}
      },
      "env" => {
        "test_env" => "value"
      },
      "foo" => "bar", # Agent env
      "baz" => "zaz"
    }
  end

  def openstack_params(unique_name, security_groups = [], nics = [], nameserver = nil)
    {
      :name => "vm-#{unique_name}",
      :image_ref => "sc-id",
      :flavor_ref => "f-test",
      :key_name => "test_key",
      :security_groups => security_groups,
      :nics => nics,
      :user_data => Yajl::Encoder.encode(user_data(unique_name, nameserver, false)),
      :personality => [ { "path" => "/var/vcap/bosh/user_data.json",
                          "contents" => Yajl::Encoder.encode(user_data(unique_name, nameserver, true))} ],
      :availability_zone => "foobar-1a"
    }
  end

  def user_data(unique_name, nameserver = nil, openssh = false)
    user_data = {
      "registry" => {
          "endpoint" => "http://registry:3333"
      },
      "server" => {
          "name" => "vm-#{unique_name}"
      }
    }
    user_data["openssh"] = { "public_key" => "public openssh key" } if openssh
    user_data["dns"] = { "nameserver" => [nameserver] } if nameserver
    user_data
  end

  let(:unique_name) { SecureRandom.uuid }
  let(:server) { double("server", :id => "i-test", :name => "i-test") }
  let(:image) { double("image", :id => "sc-id", :name => "sc-id") }
  let(:flavor) { double("flavor", :id => "f-test", :name => "m1.tiny", :ram => 1024, :ephemeral => 2) }
  let(:key_pair) { double("key_pair", :id => "k-test", :name => "test_key",
                   :fingerprint => "00:01:02:03:04", :public_key => "public openssh key") }
  
  before(:each) do
    @registry = mock_registry
  end

  it "creates an OpenStack server and polls until it's ready" do
    address = double("address", :id => "a-test", :ip => "10.0.0.1",
                     :instance_id => "i-test")

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:create).
          with(openstack_params(unique_name, %w[default], [])).and_return(server)
      openstack.security_groups.should_receive(:collect).and_return(%w[default])
      openstack.images.should_receive(:find).and_return(image)
      openstack.flavors.should_receive(:find).and_return(flavor)
      openstack.key_pairs.should_receive(:find).and_return(key_pair)
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
    network_spec = dynamic_network_spec
    network_spec["dns"] = ["1.2.3.4"]
    address = double("address", :id => "a-test", :ip => "10.0.0.1",
                     :instance_id => "i-test")

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:create).
          with(openstack_params(unique_name, %w[default], [], "1.2.3.4")).and_return(server)
      openstack.security_groups.should_receive(:collect).and_return(%w[default])
      openstack.images.should_receive(:find).and_return(image)
      openstack.flavors.should_receive(:find).and_return(flavor)
      openstack.key_pairs.should_receive(:find).and_return(key_pair)
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

  it "creates an OpenStack server with security groups" do
    security_groups = %w[bar foo]
    network_spec = dynamic_network_spec
    network_spec["cloud_properties"] ||= {}
    network_spec["cloud_properties"]["security_groups"] = security_groups
    address = double("address", :id => "a-test", :ip => "10.0.0.1",
                     :instance_id => nil)

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:create).
          with(openstack_params(unique_name, security_groups, [])).and_return(server)
      openstack.security_groups.should_receive(:collect).and_return(security_groups)
      openstack.images.should_receive(:find).and_return(image)
      openstack.flavors.should_receive(:find).and_return(flavor)
      openstack.key_pairs.should_receive(:find).and_return(key_pair)
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

  it "creates an OpenStack server with nic for dynamic network" do
    address = double("address", :id => "a-test", :ip => "10.0.0.1",
                     :instance_id => nil)
    nic = { "net_id" => "foo" }
    network_spec = dynamic_network_spec
    network_spec["cloud_properties"] ||= {}
    network_spec["cloud_properties"]["net_id"] = nic["net_id"]

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:create).
          with(openstack_params(unique_name, %w[default], [nic])).and_return(server)
      openstack.security_groups.should_receive(:collect).and_return(%w[default])
      openstack.images.should_receive(:find).and_return(image)
      openstack.flavors.should_receive(:find).and_return(flavor)
      openstack.key_pairs.should_receive(:find).and_return(key_pair)
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

  it "creates an OpenStack server with nic for manual network" do
    address = double("address", :id => "a-test", :ip => "10.0.0.1",
                     :instance_id => nil)
    nic = { "net_id" => "foo", "v4_fixed_ip" => "10.0.0.5" }
    network_spec = manual_network_spec
    network_spec["ip"] = "10.0.0.5"
    network_spec["cloud_properties"] ||= {}
    network_spec["cloud_properties"]["net_id"] = nic["net_id"]

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:create).
          with(openstack_params(unique_name, %w[default], [nic])).and_return(server)
      openstack.security_groups.should_receive(:collect).and_return(%w[default])
      openstack.images.should_receive(:find).and_return(image)
      openstack.flavors.should_receive(:find).and_return(flavor)
      openstack.key_pairs.should_receive(:find).and_return(key_pair)
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
    address = double("address", :id => "a-test", :ip => "10.0.0.1",
                     :instance_id => "i-test")

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:create).and_return(server)
      openstack.security_groups.should_receive(:collect).and_return(%w[default])
      openstack.images.should_receive(:find).and_return(image)
      openstack.flavors.should_receive(:find).and_return(flavor)
      openstack.key_pairs.should_receive(:find).and_return(key_pair)
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

  context "when cannot create an OpenStack server" do
    let(:cloud) do
      c = mock_cloud do |openstack|
        openstack.servers.should_receive(:create).and_return(server)
        openstack.security_groups.should_receive(:collect).and_return(%w[default])
        openstack.images.should_receive(:find).and_return(image)
        openstack.flavors.should_receive(:find).and_return(flavor)
        openstack.key_pairs.should_receive(:find).and_return(key_pair)
      end

      allow(c).to receive(:wait_resource).with(server, :active, :state).and_raise(Bosh::Clouds::CloudError)
      c
    end

    it "raises a Retryable Error" do
      allow(server).to receive(:destroy)

      expect {
        vm_id = cloud.create_vm("agent-id", "sc-id",
                                resource_pool_spec,
                                { "network_a" => dynamic_network_spec },
                                nil, { "test_env" => "value" })
      }.to raise_error(Bosh::Clouds::VMCreationFailed)
    end

    it "destroys the server" do
      expect(server).to receive(:destroy)

      cloud.create_vm("agent-id", "sc-id",
                      resource_pool_spec,
                      {"network_a" => dynamic_network_spec},
                      nil, {"test_env" => "value"}) rescue nil
    end
  end

  it "raises an error when a security group doesn't exist" do
    cloud = mock_cloud do |openstack|
      openstack.security_groups.should_receive(:collect).and_return(%w[foo])
    end

    expect {
      cloud.create_vm("agent-id", "sc-id", resource_pool_spec, { "network_a" => dynamic_network_spec },
                      nil, { "test_env" => "value" })
    }.to raise_error(Bosh::Clouds::CloudError, "Security group `default' not found")
  end

  it "raises an error when flavor doesn't have enough ephemeral disk capacity" do
    flavor = double("flavor", :id => "f-test", :name => "m1.tiny", :ram => 1024, :ephemeral => 1)
    cloud = mock_cloud do |openstack|
      openstack.security_groups.should_receive(:collect).and_return(%w[default])
      openstack.images.should_receive(:find).and_return(image)
      openstack.flavors.should_receive(:find).and_return(flavor)
    end

    expect {
      cloud.create_vm("agent-id", "sc-id", resource_pool_spec, { "network_a" => dynamic_network_spec },
                      nil, { "test_env" => "value" })
    }.to raise_error(Bosh::Clouds::CloudError, "Flavor `m1.tiny' should have at least 2Gb of ephemeral disk")
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
