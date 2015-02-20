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
    volume_attachments = [{"id" => "a1", "volumeId" => "v-foobar"}, {"id" => "a2", "volumeId" => "v-barfoo"}]

    cloud = mock_cloud do |openstack|
      expect(openstack.servers).to receive(:get).with("i-test").and_return(server)
      expect(openstack.volumes).to receive(:get).with("v-foobar").and_return(volume)
    end

    expect(server).to receive(:volume_attachments).and_return(volume_attachments)
    expect(volume).to receive(:detach).with(server.id, "a1").and_return(true)
    expect(cloud).to receive(:wait_resource).with(volume, :available)

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

    expect(@registry).to receive(:read_settings).with("i-test").and_return(old_settings)
    expect(@registry).to receive(:update_settings).with("i-test", new_settings)

    cloud.detach_disk("i-test", "v-foobar")
  end

  it "bypasses the detaching process when volume is not attached to a server" do
    server = double("server", :id => "i-test", :name => "i-test")
    volume = double("volume", :id => "v-barfoo")
    volume_attachments = [{"volumeId" => "v-foobar"}]

    cloud = mock_cloud do |openstack|
      expect(openstack.servers).to receive(:get).with("i-test").and_return(server)
      expect(openstack.volumes).to receive(:get).with("v-barfoo").and_return(volume)
    end

    expect(server).to receive(:volume_attachments).and_return(volume_attachments)
    expect(volume).not_to receive(:detach)

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

    expect(@registry).to receive(:read_settings).with("i-test").and_return(old_settings)
    expect(@registry).to receive(:update_settings).with("i-test", new_settings)

    cloud.detach_disk("i-test", "v-barfoo")
  end

end
