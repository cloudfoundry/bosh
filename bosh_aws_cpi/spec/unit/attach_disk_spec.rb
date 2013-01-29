# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AwsCloud::Cloud do

  before(:each) do
    @registry = mock_registry
  end

  it "attaches EC2 volume to an instance" do
    instance = double("instance", :id => "i-test")
    volume = double("volume", :id => "v-foobar")
    attachment = double("attachment", :device => "/dev/sdf")

    cloud = mock_cloud do |ec2|
      ec2.instances.should_receive(:[]).with("i-test").and_return(instance)
      ec2.volumes.should_receive(:[]).with("v-foobar").and_return(volume)
    end

    volume.should_receive(:attach_to).
      with(instance, "/dev/sdf").and_return(attachment)

    instance.should_receive(:block_device_mappings).and_return({})

    cloud.should_receive(:wait_resource).with(attachment, :attached)

    old_settings = { "foo" => "bar" }
    new_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-foobar" => "/dev/sdf"
        }
      }
    }

    @registry.should_receive(:read_settings).
      with("i-test").
      and_return(old_settings)

    @registry.should_receive(:update_settings).with("i-test", new_settings)

    cloud.attach_disk("i-test", "v-foobar")
  end

  it "picks available device name" do
    instance = double("instance", :id => "i-test")
    volume = double("volume", :id => "v-foobar")
    attachment = double("attachment", :device => "/dev/sdh")

    cloud = mock_cloud do |ec2|
      ec2.instances.should_receive(:[]).with("i-test").and_return(instance)
      ec2.volumes.should_receive(:[]).with("v-foobar").and_return(volume)
    end

    instance.should_receive(:block_device_mappings).
      and_return({ "/dev/sdf" => "foo", "/dev/sdg" => "bar" })

    volume.should_receive(:attach_to).
      with(instance, "/dev/sdh").and_return(attachment)

    cloud.should_receive(:wait_resource).with(attachment, :attached)

    old_settings = { "foo" => "bar" }
    new_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-foobar" => "/dev/sdh"
        }
      }
    }

    @registry.should_receive(:read_settings).
      with("i-test").
      and_return(old_settings)

    @registry.should_receive(:update_settings).with("i-test", new_settings)

    cloud.attach_disk("i-test", "v-foobar")
  end

  it "picks available device name" do
    instance = double("instance", :id => "i-test")
    volume = double("volume", :id => "v-foobar")
    attachment = double("attachment", :device => "/dev/sdh")

    cloud = mock_cloud do |ec2|
      ec2.instances.should_receive(:[]).with("i-test").and_return(instance)
      ec2.volumes.should_receive(:[]).with("v-foobar").and_return(volume)
    end

    instance.should_receive(:block_device_mappings).
      and_return({ "/dev/sdf" => "foo", "/dev/sdg" => "bar" })

    volume.should_receive(:attach_to).
      with(instance, "/dev/sdh").and_return(attachment)

    cloud.should_receive(:wait_resource).with(attachment, :attached)

    old_settings = { "foo" => "bar" }
    new_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-foobar" => "/dev/sdh"
        }
      }
    }

    @registry.should_receive(:read_settings).
      with("i-test").
      and_return(old_settings)

    @registry.should_receive(:update_settings).with("i-test", new_settings)

    cloud.attach_disk("i-test", "v-foobar")
  end

  it "raises an error when sdf..sdp are all reserved" do
    instance = double("instance", :id => "i-test")
    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |ec2|
      ec2.instances.should_receive(:[]).with("i-test").and_return(instance)
      ec2.volumes.should_receive(:[]).with("v-foobar").and_return(volume)
    end

    all_mappings = ("f".."p").inject({}) do |hash, char|
      hash["/dev/sd#{char}"] = "foo"
      hash
    end

    instance.should_receive(:block_device_mappings).
      and_return(all_mappings)

    expect {
      cloud.attach_disk("i-test", "v-foobar")
    }.to raise_error(Bosh::Clouds::CloudError, /too many disks attached/)
  end

end
