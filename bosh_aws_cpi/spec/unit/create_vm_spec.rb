# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::AwsCloud::Cloud, "create_vm" do
  let(:registry) { double("registry") }
  let(:region) { double("region") }
  let(:availability_zone_selector) { double("availability zone selector") }
  let(:stemcell) { double("stemcell", root_device_name: "root name", image_id: stemcell_id) }
  let(:instance_manager) { double("instance manager") }
  let(:instance) { double("instance", id: "expected instance id", status: :running) }
  let(:network_configurator) { double("network configurator") }

  let(:agent_id) { "agent_id" }
  let(:stemcell_id) { "stemcell_id" }
  let(:resource_pool) { double("resource_pool") }
  let(:networks_spec) { double("network_spec") }
  let(:disk_locality) { double("disk locality") }
  let(:environment) { "environment" }

  let(:options) {
    {
        "aws" => {
            "default_availability_zone" => "foo",
            "region" => "bar",
            "access_key_id" => "access",
            "secret_access_key" => "secret",
            "default_key_name" => "sesame"
        },
        "registry" => {
            "endpoint" => "endpoint",
            "user" => "user",
            "password" => "password"
        },
        "agent" => {
            "baz" => "qux"
        }
    }
  }

  let(:cloud) { described_class.new(options) }

  before do
    Bosh::Registry::Client.
        stub(:new).
        and_return(registry)
    AWS::EC2.
        stub(:new).
        and_return(double("ec2", regions: {"bar" => region}))
    Bosh::AwsCloud::AvailabilityZoneSelector.
        stub(:new).
        with(region, "foo").
        and_return(availability_zone_selector)
    Bosh::AwsCloud::Stemcell.
        stub(:find).
        with(region, stemcell_id).
        and_return(stemcell)
    Bosh::AwsCloud::InstanceManager.
        stub(:new).
        with(region, registry, availability_zone_selector).
        and_return(instance_manager)
    instance_manager.
        stub(:create).
        with(agent_id, stemcell_id, resource_pool, networks_spec, disk_locality, environment, options).
        and_return(instance)
    Bosh::AwsCloud::NetworkConfigurator.
        stub(:new).
        with(networks_spec).
        and_return(network_configurator)

    resource_pool.stub(:[]).and_return(false)
    cloud.stub(:task_checkpoint)
  end

  it 'passes the image_id of the stemcell to an InstanceManager in order to create a VM' do
    network_configurator.stub(:configure)
    registry.stub(:update_settings)

    stemcell.should_receive(:image_id).with(no_args).and_return('ami-1234')
    instance_manager.should_receive(:create).with(
      anything,
      'ami-1234',
      anything,
      anything,
      anything,
      anything,
      anything,
    ).and_return(instance)
    cloud.create_vm(agent_id, stemcell_id, resource_pool, networks_spec, disk_locality, environment).should == "expected instance id"
  end

  it "should create an EC2 instance and return its id" do
    network_configurator.stub(:configure)
    registry.stub(:update_settings)
    Bosh::AwsCloud::ResourceWait.stub(:for_instance).with(instance: instance, state: :running)

    cloud.create_vm(agent_id, stemcell_id, resource_pool, networks_spec, disk_locality, environment).should == "expected instance id"
  end

  it "should configure the IP for the created instance according to the network specifications" do
    registry.stub(:update_settings)
    Bosh::AwsCloud::ResourceWait.stub(:for_instance).with(instance: instance, state: :running)

    network_configurator.should_receive(:configure).with(region, instance)

    cloud.create_vm(agent_id, stemcell_id, resource_pool, networks_spec, disk_locality, environment)
  end

  it "should update the registry settings with the new instance" do
    network_configurator.stub(:configure)
    Bosh::AwsCloud::ResourceWait.stub(:for_instance).with(instance: instance, state: :running)
    SecureRandom.stub(:uuid).and_return("rand0m")

    agent_settings = {
        "vm" => {
            "name" => "vm-rand0m"
        },
        "agent_id" => agent_id,
        "networks" => networks_spec,
        "disks" => {
            "system" => "root name",
            "ephemeral" => "/dev/sdb",
            "persistent" => {}
        },
        "env" => environment,
        "baz" => "qux"
    }
    registry.should_receive(:update_settings).with("expected instance id", agent_settings)

    cloud.create_vm(agent_id, stemcell_id, resource_pool, networks_spec, disk_locality, environment)
  end

  it 'should clean up after itself if something fails' do
    network_configurator.stub(:configure)
    registry.stub(:update_settings).and_raise(ArgumentError)
    Bosh::AwsCloud::ResourceWait.stub(:for_instance).with(instance: instance, state: :running)

    instance_manager.should_receive(:terminate)

    expect {
      cloud.create_vm(agent_id, stemcell_id, resource_pool, networks_spec, disk_locality, environment)
    }.to raise_error(ArgumentError)
  end
end
