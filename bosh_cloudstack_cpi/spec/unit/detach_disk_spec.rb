# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::CloudStackCloud::Cloud do

  before(:each) do
    @registry = mock_registry
  end

  it "detaches an CloudStack volume from a server" do
    server = double("server", :id => "i-test", :name => "i-test")
    volume = double("volume", :id => "v-foobar", :server_id => "i-test")
    job = generate_job

    cloud = mock_cloud do |compute|
      compute.servers.should_receive(:get).with("i-test").and_return(server)
      compute.volumes.should_receive(:get).with("v-foobar").and_return(volume)
    end

    volume.should_receive(:reload)
    volume.should_receive(:detach).and_return(job)
    cloud.should_receive(:wait_job).with(job)

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
    volume = double("volume", :id => "v-barfoo", :server_id => nil)
    job = generate_job

    cloud = mock_cloud do |compute|
      compute.servers.should_receive(:get).with("i-test").and_return(server)
      compute.volumes.should_receive(:get).with("v-barfoo").and_return(volume)
    end

    volume.should_receive(:reload)
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
