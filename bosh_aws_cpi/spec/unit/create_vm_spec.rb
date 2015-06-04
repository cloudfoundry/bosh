require "spec_helper"

describe Bosh::AwsCloud::Cloud, "create_vm" do
  let(:registry) { double("registry") }
  let(:region) { double("region", name: 'bar') }
  let(:availability_zone_selector) { double("availability zone selector") }
  let(:stemcell) { double("stemcell", root_device_name: "root name", image_id: stemcell_id) }
  let(:instance_manager) { instance_double("Bosh::AwsCloud::InstanceManager") }
  let(:instance) { instance_double("Bosh::AwsCloud::Instance", id: "fake-id") }
  let(:network_configurator) { double("network configurator") }

  let(:agent_id) { "agent_id" }
  let(:stemcell_id) { "stemcell_id" }
  let(:resource_pool) { {} }
  let(:networks_spec) { double("network_spec") }
  let(:disk_locality) { double("disk locality") }
  let(:environment) { "environment" }

  let(:options) do
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
  end

  let(:cloud) do
    cloud = described_class.new(options)
    allow(cloud).to receive(:task_checkpoint)
    cloud
  end

  before do
    allow(Bosh::Registry::Client).to receive(:new).and_return(registry)

    allow(AWS::EC2).to receive(:new).and_return(double("ec2", regions: [ region ]))

    allow(Bosh::AwsCloud::AvailabilityZoneSelector).to receive(:new).
        with(region, "foo").
        and_return(availability_zone_selector)

    allow(Bosh::AwsCloud::Stemcell).to receive(:find).with(region, stemcell_id).and_return(stemcell)

    allow(Bosh::AwsCloud::InstanceManager).to receive(:new).
        with(region, registry, be_an_instance_of(AWS::ELB), availability_zone_selector, be_an_instance_of(Logger)).
        and_return(instance_manager)

    allow(instance_manager).to receive(:create).
        with(agent_id, stemcell_id, resource_pool, networks_spec, disk_locality, environment, options).
        and_return(instance)

    allow(Bosh::AwsCloud::NetworkConfigurator).to receive(:new).
        with(networks_spec).
        and_return(network_configurator)

    allow(resource_pool).to receive(:[]).and_return(false)
    allow(network_configurator).to receive(:configure)
    allow(registry).to receive(:update_settings)
  end

  it 'passes the image_id of the stemcell to an InstanceManager in order to create a VM' do
    expect(stemcell).to receive(:image_id).with(no_args).and_return('ami-1234')
    expect(instance_manager).to receive(:create).with(
      anything,
      'ami-1234',
      anything,
      anything,
      anything,
      anything,
      anything,
    ).and_return(instance)
    expect(cloud.create_vm(agent_id, stemcell_id, resource_pool, networks_spec, disk_locality, environment)).to eq("fake-id")
  end

  it "should create an EC2 instance and return its id" do
    allow(Bosh::AwsCloud::ResourceWait).to receive(:for_instance).with(instance: instance, state: :running)
    expect(cloud.create_vm(agent_id, stemcell_id, resource_pool, networks_spec, disk_locality, environment)).to eq("fake-id")
  end

  it "should configure the IP for the created instance according to the network specifications" do
    allow(Bosh::AwsCloud::ResourceWait).to receive(:for_instance).with(instance: instance, state: :running)
    expect(network_configurator).to receive(:configure).with(region, instance)
    cloud.create_vm(agent_id, stemcell_id, resource_pool, networks_spec, disk_locality, environment)
  end

  it "should update the registry settings with the new instance" do
    allow(Bosh::AwsCloud::ResourceWait).to receive(:for_instance).with(instance: instance, state: :running)
    allow(SecureRandom).to receive(:uuid).and_return("rand0m")

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
    expect(registry).to receive(:update_settings).with("fake-id", agent_settings)

    cloud.create_vm(agent_id, stemcell_id, resource_pool, networks_spec, disk_locality, environment)
  end

  it 'terminates instance if updating registry settings fails' do
    allow(network_configurator).to receive(:configure).and_raise(StandardError)
    expect(instance).to receive(:terminate)

    expect {
      cloud.create_vm(agent_id, stemcell_id, resource_pool, networks_spec, disk_locality, environment)
    }.to raise_error(StandardError)
  end

  it 'terminates instance if updating registry settings fails' do
    allow(registry).to receive(:update_settings).and_raise(StandardError)
    expect(instance).to receive(:terminate)

    expect {
      cloud.create_vm(agent_id, stemcell_id, resource_pool, networks_spec, disk_locality, environment)
    }.to raise_error(StandardError)
  end

  it 'creates elb client with correct region' do
    expect(Bosh::AwsCloud::InstanceManager).to receive(:new) do |_, _, elb, _, _|
      expect(elb.config.region).to eq('bar')
    end.once.and_return(instance_manager)

    cloud.create_vm(agent_id, stemcell_id, resource_pool, networks_spec, disk_locality, environment)
  end
end
