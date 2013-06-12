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

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:get).with("i-test").and_return(server)
      openstack.volumes.should_receive(:get).with("v-foobar").and_return(volume)
    end

    server.should_receive(:volume_attachments).and_return([])
    volume.should_receive(:attach).with(server.id, nil)
    cloud.should_receive(:wait_resource).with(volume, :"in-use")
    server.should_receive(:volume_attachments).and_return([{"volumeId" => "v-foobar", "device" => "/dev/sdc"}])

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

  it "raises an error when OpenStack is unable to attach the volume" do
    server = double("server", :id => "i-test", :name => "i-test")
    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:get).with("i-test").and_return(server)
      openstack.volumes.should_receive(:get).with("v-foobar").and_return(volume)
    end

    server.should_receive(:volume_attachments).and_return([])
    volume.should_receive(:attach).with(server.id, nil)
    cloud.should_receive(:wait_resource).with(volume, :"in-use")
    server.should_receive(:volume_attachments).and_return([])
    
    expect {
      cloud.attach_disk("i-test", "v-foobar")
    }.to raise_error(Bosh::Clouds::CloudError, "Unable to attach volume `v-foobar' to server `i-test'")
  end

  it "bypasses the attaching process when volume is already attached to a server" do
    server = double("server", :id => "i-test", :name => "i-test")
    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:get).with("i-test").and_return(server)
      openstack.volumes.should_receive(:get).with("v-foobar").and_return(volume)
    end

    server.should_receive(:volume_attachments).and_return([{"volumeId" => "v-foobar", "device" => "/dev/sdc"}])
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
