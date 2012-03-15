# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AWSCloud::Cloud, "create_vm" do

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

    ec2_params = {
      :image_id => "sc-id",
      :count => 1,
      :key_name => "test_key",
      :security_groups => [],
      :instance_type => "m3.zb",
      :user_data => Yajl::Encoder.encode(user_data),
      :availability_zone => "foobar-1a"
    }

    agent_settings = {
      "vm" => {
        "name" => "vm-#{unique_name}"
      },
      "agent_id" => "agent-id",
      "networks" => { "network_a" => dynamic_network_spec },
      "disks" => {
        "system" => "/dev/sda",
        "ephemeral" => "/dev/sdb",
        "persistent" => {}
      },
      "env" => {
        "test_env" => "value"
      },
      "foo" => "bar", # Agent env
      "baz" => "zaz"
    }

    instance = double("instance",
                      :id => "i-test",
                      :elastic_ip => nil)

    cloud = mock_cloud do |ec2|
      ec2.instances.should_receive(:create).
        with(ec2_params).
        and_return(instance)
    end

    instance.should_receive(:status).and_return(:pending)
    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    cloud.should_receive(:wait_resource).with(instance, :pending, :running)
    @registry.should_receive(:update_settings).with("i-test", agent_settings)
    vm_id = cloud.create_vm("agent-id", "sc-id",
                            resource_pool_spec,
                            { "network_a" => dynamic_network_spec },
                            nil, { "test_env" => "value" })

    vm_id.should == "i-test"
  end

  it "associates instance with elastic ip if vip network is provided" do
    instance = double("instance",
                      :id => "i-test",
                      :elastic_ip => nil)

    cloud = mock_cloud do |ec2|
      ec2.instances.should_receive(:create).and_return(instance)
    end

    instance.should_receive(:status).and_return(:pending)
    instance.should_receive(:associate_elastic_ip).with("10.0.0.1")
    cloud.should_receive(:wait_resource).with(instance, :pending, :running)
    @registry.should_receive(:update_settings)

    vm_id = cloud.create_vm("agent-id", "sc-id",
                            resource_pool_spec,
                            combined_network_spec)
  end

end
