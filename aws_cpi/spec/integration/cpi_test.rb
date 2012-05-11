# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

require "tempfile"

describe Bosh::AwsCloud::Cloud do

  before(:each) do
    unless ENV["CPI_CONFIG_FILE"]
      raise "Please provide CPI_CONFIG_FILE environment variable"
    end
    @config = YAML.load_file(ENV["CPI_CONFIG_FILE"])
    @logger = Logger.new(STDOUT)
  end

  let(:cpi) do
    cpi = Bosh::AwsCloud::Cloud.new(@config)
    cpi.logger = @logger

    # As we inject the configuration file from the outside, we don't care
    # about spinning up the registry ourselves. However we don't want to bother
    # EC2 at all if registry is not working, so just in case we perform a test
    # health check against whatever has been provided.
    cpi.registry.update_settings("foo", { "bar" => "baz" })
    cpi.registry.read_settings("foo").should == { "bar" => "baz"}

    cpi
  end

  it "exercises a VM lifecycle" do
    instance_id = cpi.create_vm(
      "agent-007", "ami-809a48e9",
      { "instance_type" => "m1.small" },
      { "default" => { "type" => "dynamic" }},
      [], { "key" => "value" })

    instance_id.should_not be_nil

    settings = cpi.registry.read_settings(instance_id)
    settings["vm"].should be_a(Hash)
    settings["vm"]["name"].should_not be_nil
    settings["agent_id"].should == "agent-007"
    settings["networks"].should == { "default" => { "type" => "dynamic" }}
    settings["disks"].should == {
      "system" => "/dev/sda",
      "ephemeral" => "/dev/sdb",
      "persistent" => {}
    }

    settings["env"].should == { "key" => "value" }

    volume_id = cpi.create_disk(2048)
    volume_id.should_not be_nil

    cpi.attach_disk(instance_id, volume_id)
    settings = cpi.registry.read_settings(instance_id)
    settings["disks"]["persistent"].should == { volume_id => "/dev/sdf" }

    cpi.detach_disk(instance_id, volume_id)
    settings = cpi.registry.read_settings(instance_id)
    settings["disks"]["persistent"].should == {}

    # TODO: test configure_networks (need an elastic IP at hand for that)

    cpi.delete_vm(instance_id)
    cpi.delete_disk(volume_id)

    # Test below would fail: EC2 still reports the instance as 'terminated'
    # for some time.
    # cpi.ec2.instances[instance_id].should be_nil

    expect {
      cpi.registry.read_settings(instance_id)
    }.to raise_error(/HTTP 404/)
  end

end