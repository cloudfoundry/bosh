# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Cloud do

  before(:each) do
    @registry = mock_registry
  end

  it "detaches an OpenStack volume from a server" do
    server = double("server", :id => "i-test", :name => "i-test")
    volume = double("volume", :id => "v-foobar")
    volume_attachments = [{"volumeId" => "v-foobar"}, {"volumeId" => "v-barfoo"}]

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:get).with("i-test").and_return(server)
      openstack.volumes.should_receive(:get).with("v-foobar").and_return(volume)
    end

    server.should_receive(:volume_attachments).and_return(volume_attachments)
    volume.should_receive(:detach).with(server.id, "v-foobar").and_return(true)
    cloud.should_receive(:wait_resource).with(volume, :available)

    old_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-foobar" => "/dev/vdc",
          "v-barfoo" => "/dev/vdd"
        }
      }
    }

    new_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-barfoo" => "/dev/vdd"
        }
      }
    }

    @registry.should_receive(:read_settings).with("i-test").and_return(old_settings)
    @registry.should_receive(:update_settings).with("i-test", new_settings)

    cloud.detach_disk("i-test", "v-foobar")
  end

  it "bypasses the detaching process when volume is not attached to a server" do
    server = double("server", :id => "i-test", :name => "i-test")
    volume = double("volume", :id => "v-barfoo")
    volume_attachments = [{"volumeId" => "v-foobar"}]

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:get).with("i-test").and_return(server)
      openstack.volumes.should_receive(:get).with("v-barfoo").and_return(volume)
    end

    server.should_receive(:volume_attachments).and_return(volume_attachments)
    volume.should_not_receive(:detach)

    old_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-foobar" => "/dev/vdc",
          "v-barfoo" => "/dev/vdd"
        }
      }
    }

    new_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-foobar" => "/dev/vdc"
        }
      }
    }

    @registry.should_receive(:read_settings).with("i-test").and_return(old_settings)
    @registry.should_receive(:update_settings).with("i-test", new_settings)

    cloud.detach_disk("i-test", "v-barfoo")
  end

end
