# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AwsCloud::Cloud, "create_vm" do

  def agent_settings(unique_name, network_spec=dynamic_network_spec)
    {
      "vm" => {
        "name" => "vm-#{unique_name}"
      },
      "agent_id" => "agent-id",
      "networks" => { "network_a" => network_spec },
      "disks" => {
        "system" => "/dev/sda1",
        "ephemeral" => "/dev/sdb",
        "persistent" => {}
      },
      "env" => {
        "test_env" => "value"
      },
      "foo" => "bar", # Agent env
      "baz" => "zaz"
    }
  end

  def fake_image_set
    image = double("image", :root_device_name => "/dev/sda1")
    double("images_set", :images_set => [image])
  end

  def ec2_params(user_data, security_groups=[])
    {
      :image_id => "sc-id",
      :count => 1,
      :key_name => "test_key",
      :security_groups => security_groups,
      :instance_type => "m3.zb",
      :user_data => Yajl::Encoder.encode(user_data),
      :availability_zone => "foobar-1a"
    }
  end

  before(:each) do
    @registry = mock_registry
  end

  it "creates EC2 instance and polls until it's ready" do
    unique_name = UUIDTools::UUID.random_create.to_s

    user_data = {
      "registry" => {
        "endpoint" => "http://registry:3333"
      }
    }

    instance = double("instance",
                      :id => "i-test",
                      :elastic_ip => nil)
    client = double("client", :describe_images => fake_image_set)

    cloud = mock_cloud do |ec2|
      ec2.instances.should_receive(:create).
        with(ec2_params(user_data)).
        and_return(instance)
      ec2.should_receive(:client).and_return(client)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    cloud.should_receive(:wait_resource).with(instance, :running)
    @registry.should_receive(:update_settings)
      .with("i-test", agent_settings(unique_name))

    vm_id = cloud.create_vm("agent-id", "sc-id",
                            resource_pool_spec,
                            { "network_a" => dynamic_network_spec },
                            nil, { "test_env" => "value" })

    vm_id.should == "i-test"
  end

  it "creates EC2 instance with security group" do
    unique_name = UUIDTools::UUID.random_create.to_s

    user_data = {
      "registry" => {
        "endpoint" => "http://registry:3333"
      }
    }

    instance = double("instance",
                      :id => "i-test",
                      :elastic_ip => nil)
    client = double("client", :describe_images => fake_image_set)

    security_groups = %w[foo bar]
    network_spec = dynamic_network_spec
    network_spec["cloud_properties"] = {
      "security_groups" => security_groups
    }

    cloud = mock_cloud do |ec2|
      ec2.instances.should_receive(:create).
        with(ec2_params(user_data, security_groups)).
        and_return(instance)
      ec2.should_receive(:client).and_return(client)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    cloud.should_receive(:wait_resource).with(instance, :running)
    @registry.should_receive(:update_settings)
      .with("i-test", agent_settings(unique_name, network_spec))

    vm_id = cloud.create_vm("agent-id", "sc-id",
                            resource_pool_spec,
                            { "network_a" => network_spec },
                            nil, { "test_env" => "value" })

    vm_id.should == "i-test"
  end

  it "associates instance with elastic ip if vip network is provided" do
    instance = double("instance",
                      :id => "i-test",
                      :elastic_ip => nil)
    client = double("client", :describe_images => fake_image_set)

    cloud = mock_cloud do |ec2|
      ec2.instances.should_receive(:create).and_return(instance)
      ec2.should_receive(:client).and_return(client)
    end

    instance.should_receive(:associate_elastic_ip).with("10.0.0.1")
    cloud.should_receive(:wait_resource).with(instance, :running)
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

    it "should select the default availability_zone when all values are nil" do
      cloud = mock_cloud
      cloud.select_availability_zone(nil, nil).should ==
        Bosh::AwsCloud::Cloud::DEFAULT_AVAILABILITY_ZONE
    end

    it "should select the zone from a list of disks" do
      cloud = mock_cloud do |ec2|
        ec2.volumes.stub(:[]).and_return(volume("foo"), volume("foo"))
      end
      cloud.select_availability_zone(%w[cid1 cid2], nil).should == "foo"
    end

    it "should select the zone from a list of disks and a default" do
      cloud = mock_cloud do |ec2|
        ec2.volumes.stub(:[]).and_return(volume("foo"), volume("foo"))
      end
      cloud.select_availability_zone(%w[cid1 cid2], "foo").should == "foo"
    end
  end

  describe "#ensure_same_availability_zone" do
    it "should raise an error when the zones differ" do
      cloud = mock_cloud
      lambda {
        cloud.ensure_same_availability_zone([volume("foo"), volume("bar")], nil)
      }.should raise_error Bosh::Clouds::CloudError
    end

    it "should raise an error when the zones differ" do
      cloud = mock_cloud
      lambda {
        cloud.ensure_same_availability_zone([volume("foo"), volume("bar")], "foo")
      }.should raise_error Bosh::Clouds::CloudError
    end

    it "should raise an error when the zones differ" do
      cloud = mock_cloud
      lambda {
        cloud.ensure_same_availability_zone([volume("foo"), volume("foo")], "bar")
      }.should raise_error Bosh::Clouds::CloudError
    end
  end

end
