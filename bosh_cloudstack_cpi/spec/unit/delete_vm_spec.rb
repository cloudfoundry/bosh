# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::CloudStackCloud::Cloud do

  before(:each) do
    @server = double("server")
    @volume = double("volume")
    @registry = mock_registry
    @job = generate_job
    @ephemeral_settings =
      {
        "disks" => {
          "persistent" => {},
          "ephemeral" => "/dev/sdb",
        }
      }
    @no_ephemeral_settings = {
      "disks" => {
        "persistent" => {},
        "ephemeral" => nil,
        }
      }
  end

  it "deletes no CloudStack server" do
    cloud = mock_cloud do |compute|
      compute.servers.should_receive(:get).with("i-no_server").and_return(nil)
    end
    cloud.delete_vm("i-no_server")
  end

  it "deletes the CloudStack server without an ephemeral disk" do
    cloud = mock_cloud do |compute|
      compute.servers.should_receive(:get).with("i-no_ephemeral").and_return(@server)
      compute.volumes.should_not_receive(:select)
    end

    @registry.should_receive(:read_settings).with("i-no_ephemeral").and_return(@no_ephemeral_settings)
    @server.should_receive(:id).and_return("i-no_ephemeral")
    @server.should_receive(:name).exactly(2).and_return("i-no_ephemeral")
    @server.should_receive(:destroy).and_return(@job)
    cloud.should_receive(:wait_job).with(@job)
    @registry.should_receive(:delete_settings).with("i-no_ephemeral")

    cloud.delete_vm("i-no_ephemeral")
  end

  it "deletes the CloudStack server with the ephemeral disk" do
    volume_tobe_deleted = double("sdb", :id => "ok", :device_id => 1)
    cloud = mock_cloud do |compute|
      compute.servers.should_receive(:get).with("i-ephemeral").and_return(@server)
      compute.volumes.should_receive(:select).and_return([
          double("sda", :id => "ng", :device_id => 0),
          volume_tobe_deleted,
          double("sdc", :id => "yetanotherng", :device_id => 2),
        ])
    end

    @registry.should_receive(:read_settings).with("i-ephemeral").and_return(@ephemeral_settings)
    @server.should_receive(:id).and_return("i-ephemeral")
    @server.should_receive(:name).exactly(2).and_return("i-ephemeral")
    @server.should_receive(:destroy).and_return(@job)
    cloud.should_receive(:wait_job).with(@job)
    @registry.should_receive(:delete_settings).with("i-ephemeral")

    volume_tobe_deleted.should_receive(:server_id).and_return("ok")
    volume_tobe_deleted.should_receive(:detach)
    cloud.should_receive(:wait_resource).with(volume_tobe_deleted, :"", :server_id)
    cloud.should_receive(:delete_disk).with("ok")

    cloud.delete_vm("i-ephemeral")
  end

end
