# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::CloudStackCloud::Cloud, "create_vm" do

  def agent_settings(unique_name, network_spec = dynamic_network_spec, ephemeral = nil)
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

  def server_params(unique_name, security_groups = [], nics = [], nameserver = nil)
    {
      :name => "vm-#{unique_name}",
      :template_id => "sc-id",
      :service_offering_id => "f-test",
      :key_name => "test_key",
      :security_groups => security_groups,
      :user_data => Base64.strict_encode64(Yajl::Encoder.encode(user_data(unique_name, nameserver, false))),
      :zone_id => "foobar-1a"
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
  let(:security_groups) { [double('default', :name => 'default')] }

  before(:each) do
    @registry = mock_registry
  end

  it "creates an CloudStack server and polls until it's ready" do
    cloud = mock_cloud do |compute|
      compute.servers.should_receive(:create).
          with(server_params(unique_name, security_groups, [])).and_return(server)
      compute.should_receive(:security_groups).and_return(security_groups)
      compute.images.should_receive(:find).and_return(image)
      compute.flavors.should_receive(:find).and_return(flavor)
      compute.key_pairs.should_receive(:find).and_return(key_pair)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    cloud.should_receive(:wait_resource).with(server, :running)

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

    cloud = mock_cloud do |compute|
      compute.servers.should_receive(:create).
          with(server_params(unique_name, security_groups, [], "1.2.3.4")).and_return(server)
      compute.should_receive(:security_groups).and_return(security_groups)
      compute.images.should_receive(:find).and_return(image)
      compute.flavors.should_receive(:find).and_return(flavor)
      compute.key_pairs.should_receive(:find).and_return(key_pair)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    cloud.should_receive(:wait_resource).with(server, :running)

    @registry.should_receive(:update_settings).
        with("i-test", agent_settings(unique_name, network_spec))

    vm_id = cloud.create_vm("agent-id", "sc-id",
                            resource_pool_spec,
                            { "network_a" => network_spec },
                            nil, { "test_env" => "value" })
    vm_id.should == "i-test"
  end

  it "creates an CloudStack server with security groups" do
    security_groups = [double("foo", :name => 'foo'), double("bar", :name => 'bar')]
    network_spec = dynamic_network_spec
    network_spec["cloud_properties"] ||= {}
    network_spec["cloud_properties"]["security_groups"] = ['foo', 'bar']

    cloud = mock_cloud do |compute|
      compute.servers.should_receive(:create).
          with(server_params(unique_name, security_groups, [])).and_return(server)
      compute.should_receive(:security_groups).and_return(security_groups)
      compute.images.should_receive(:find).and_return(image)
      compute.flavors.should_receive(:find).and_return(flavor)
      compute.key_pairs.should_receive(:find).and_return(key_pair)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    cloud.should_receive(:wait_resource).with(server, :running)

    @registry.should_receive(:update_settings).
        with("i-test", agent_settings(unique_name, network_spec))

    vm_id = cloud.create_vm("agent-id", "sc-id",
                            resource_pool_spec,
                            { "network_a" => network_spec },
                            nil, { "test_env" => "value" })
    vm_id.should == "i-test"
  end

  it "associates server with floating ip if vip network is provided" do
    # TODO
  end

  it "raises a Retryable Error when cannot create an CloudStack server" do
    cloud = mock_cloud do |compute|
      compute.servers.should_receive(:create).and_return(server)
      compute.should_receive(:security_groups).and_return(security_groups)
      compute.images.should_receive(:find).and_return(image)
      compute.flavors.should_receive(:find).and_return(flavor)
      compute.key_pairs.should_receive(:find).and_return(key_pair)
    end

    cloud.should_receive(:wait_resource).with(server, :running).and_raise(Bosh::Clouds::CloudError)

    expect {
      vm_id = cloud.create_vm("agent-id", "sc-id",
                              resource_pool_spec,
                              { "network_a" => dynamic_network_spec },
                              nil, { "test_env" => "value" })
    }.to raise_error(Bosh::Clouds::VMCreationFailed)
  end

  it "raises an error when a security group doesn't exist" do
    cloud = mock_cloud do |compute|
      compute.should_receive(:security_groups).and_return([])
    end

    expect {
      cloud.create_vm("agent-id", "sc-id", resource_pool_spec, { "network_a" => dynamic_network_spec },
                      nil, { "test_env" => "value" })
    }.to raise_error(Bosh::Clouds::CloudError, "Security group `default' not found")
  end

  it "raises an error when ephemeral volume offering does not exists" do
    cloud = mock_cloud do |compute|
      compute.should_receive(:security_groups).and_return(security_groups)
      compute.images.should_receive(:find).and_return(image)
      compute.flavors.should_receive(:find).and_return(flavor)
      compute.key_pairs.should_receive(:find).and_return(key_pair)
    end

    spec = resource_pool_spec
    spec["ephemeral_volume"] = "foobar-offering"
    expect {
      cloud.create_vm("agent-id", "sc-id", spec, { "network_a" => dynamic_network_spec },
                      nil, { "test_env" => "value" })
    }.to raise_error(Bosh::Clouds::CloudError, "Disk offering `foobar-offering' not found")
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
      cloud = mock_cloud do |compute|
        compute.volumes.stub(:get).and_return(volume("foo"), volume("foo"))
      end
      cloud.select_availability_zone(%w[cid1 cid2], nil).should == "foo"
    end

    it "should select the zone from a list of disks and a default" do
      cloud = mock_cloud do |compute|
        compute.volumes.stub(:get).and_return(volume("foo"), volume("foo"))
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
