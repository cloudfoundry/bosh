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
    volume_attachments = double("body", :body => {"volumeAttachments" => []})
    attachment = double("attachment", :device => "/dev/vdc")

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:get).
        with("i-test").and_return(server)
      openstack.volumes.should_receive(:get).
        with("v-foobar").and_return(volume)
      openstack.should_receive(:get_server_volumes).
        and_return(volume_attachments)
    end

    volume.should_receive(:attach).
      with(server.id, "/dev/vdc").and_return(attachment)
    cloud.should_receive(:wait_resource).with(volume, :"in-use")

    old_settings = { "foo" => "bar" }
    new_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-foobar" => "/dev/vdc"
        }
      }
    }

    @registry.should_receive(:read_settings).
      with("i-test").and_return(old_settings)
    @registry.should_receive(:update_settings).
      with("i-test", new_settings)

    cloud.attach_disk("i-test", "v-foobar")
  end

  it "picks available device name" do
    server = double("server", :id => "i-test", :name => "i-test")
    volume = double("volume", :id => "v-foobar")
    volume_attachments = double("body", :body => {"volumeAttachments" =>
                                                  [{"device" => "/dev/vdc"},
                                                   {"device" => "/dev/vdd"}]})
    attachment = double("attachment", :device => "/dev/vdd")

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:get).
        with("i-test").and_return(server)
      openstack.volumes.should_receive(:get).
        with("v-foobar").and_return(volume)
      openstack.should_receive(:get_server_volumes).
        and_return(volume_attachments)
    end

    volume.should_receive(:attach).
      with(server.id, "/dev/vde").and_return(attachment)
    cloud.should_receive(:wait_resource).with(volume, :"in-use")

    old_settings = { "foo" => "bar" }
    new_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-foobar" => "/dev/vde"
        }
      }
    }

    @registry.should_receive(:read_settings).
      with("i-test").and_return(old_settings)
    @registry.should_receive(:update_settings).
      with("i-test", new_settings)

    cloud.attach_disk("i-test", "v-foobar")
  end

  it "raises an error when vdc..vdz are all reserved" do
    server = double("server", :id => "i-test", :name => "i-test")
    volume = double("volume", :id => "v-foobar")
    all_mappings = ("c".."z").inject([]) do |array, char|
      array << {"device" => "/dev/vd#{char}"}
      array
    end
    volume_attachments = double("body", :body => {"volumeAttachments" =>
                                                   all_mappings})

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:get).
        with("i-test").and_return(server)
      openstack.volumes.should_receive(:get).
        with("v-foobar").and_return(volume)
      openstack.should_receive(:get_server_volumes).
        and_return(volume_attachments)
    end

    expect {
      cloud.attach_disk("i-test", "v-foobar")
    }.to raise_error(Bosh::Clouds::CloudError, /too many disks attached/)
  end

 end
