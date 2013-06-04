# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Cloud do

  before(:each) do
    @registry = mock_registry
  end

  it "attaches an OpenStack volume to a server" do
    server = double("server", :id => "i-test", :name => "i-test")
    volume = double("volume", :id => "v-foobar")
    volume_attachments = []
    attachment = double("attachment", :device => "/dev/sdc")

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:get).with("i-test").and_return(server)
      openstack.volumes.should_receive(:get).with("v-foobar").and_return(volume)
    end

    server.should_receive(:volume_attachments).and_return(volume_attachments)
    volume.should_receive(:attach).with(server.id, "/dev/sdc").and_return(attachment)
    cloud.should_receive(:wait_resource).with(volume, :"in-use")

    old_settings = { "foo" => "bar" }
    new_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-foobar" => "/dev/sdc"
        }
      }
    }

    @registry.should_receive(:read_settings).with("i-test").and_return(old_settings)
    @registry.should_receive(:update_settings).with("i-test", new_settings)

    cloud.attach_disk("i-test", "v-foobar")
  end

  it "picks available device name" do
    server = double("server", :id => "i-test", :name => "i-test")
    volume = double("volume", :id => "v-foobar")
    volume_attachments = [{"volumeId" => "v-c", "device" => "/dev/sdc"},
                          {"volumeId" => "v-d", "device" => "/dev/sdd"}]
    attachment = double("attachment", :device => "/dev/sdd")

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:get).with("i-test").and_return(server)
      openstack.volumes.should_receive(:get).with("v-foobar").and_return(volume)
    end

    server.should_receive(:volume_attachments).and_return(volume_attachments)
    volume.should_receive(:attach).with(server.id, "/dev/sde").and_return(attachment)
    cloud.should_receive(:wait_resource).with(volume, :"in-use")

    old_settings = { "foo" => "bar" }
    new_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-foobar" => "/dev/sde"
        }
      }
    }

    @registry.should_receive(:read_settings).with("i-test").and_return(old_settings)
    @registry.should_receive(:update_settings).with("i-test", new_settings)

    cloud.attach_disk("i-test", "v-foobar")
  end

  it "raises an error when sdc..sdz are all reserved" do
    server = double("server", :id => "i-test", :name => "i-test")
    volume = double("volume", :id => "v-foobar")
    volume_attachments = ("c".."z").inject([]) do |array, char|
      array << {"volumeId" => "v-#{char}", "device" => "/dev/sd#{char}"}
      array
    end

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:get).with("i-test").and_return(server)
      openstack.volumes.should_receive(:get).with("v-foobar").and_return(volume)
    end

    server.should_receive(:volume_attachments).and_return(volume_attachments)

    expect {
      cloud.attach_disk("i-test", "v-foobar")
    }.to raise_error(Bosh::Clouds::CloudError, /too many disks attached/)
  end

  it "bypasses the attaching process when volume is already attached to a server" do
    server = double("server", :id => "i-test", :name => "i-test")
    volume = double("volume", :id => "v-foobar")
    volume_attachments = [{"volumeId" => "v-foobar", "device" => "/dev/sdc"}]
    attachment = double("attachment", :device => "/dev/sdd")

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:get).with("i-test").and_return(server)
      openstack.volumes.should_receive(:get).with("v-foobar").and_return(volume)
    end

    server.should_receive(:volume_attachments).and_return(volume_attachments)
    volume.should_not_receive(:attach)

    old_settings = { "foo" => "bar" }
    new_settings = {
        "foo" => "bar",
        "disks" => {
            "persistent" => {
                "v-foobar" => "/dev/sdc"
            }
        }
    }

    @registry.should_receive(:read_settings).with("i-test").and_return(old_settings)
    @registry.should_receive(:update_settings).with("i-test", new_settings)

    cloud.attach_disk("i-test", "v-foobar")
  end
 end
