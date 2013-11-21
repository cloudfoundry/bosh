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
          "persistent"=>{},
          "ephemeral"=>"/dev/sdb",
        }
      }
    @no_ephemeral_settings =
      {
        "disks" => {
          "persistent"=>{},
          "ephemeral"=>nil
        }
      }
  end

  it "deletes no CloudStack server" do
    cloud = mock_cloud do |compute|
      compute.servers.should_receive(:get).with("i-no_server").and_return(nil)
    end
    cloud.delete_vm("i-no_server")
  end

  it "deletes an CloudStack server without ephemeral disk" do
    cloud = mock_cloud do |compute|
      compute.servers.should_receive(:get).with("i-no_ephemeral").and_return(@server)
      compute.volumes.should_receive(:get).with(nil).and_return(nil)
    end
    @server.should_receive(:id).and_return("i-no_ephemeral")
    @server.should_receive(:name).exactly(2).and_return("i-no_ephemeral")
    @server.should_receive(:destroy).and_return(@job)
    cloud.should_receive(:wait_job).with(@job)
    @registry.should_receive(:read_settings).with("i-no_ephemeral").and_return(@no_ephemeral_settings)
    @registry.should_receive(:delete_settings).with("i-no_ephemeral")

    cloud.delete_vm("i-no_ephemeral")
  end

  it "deletes an CloudStack server with an ephemeral disk" do
    cloud = mock_cloud do |compute|
      compute.servers.should_receive(:get).with("i-ephemeral").and_return(@server)
      compute.volumes.should_receive(:get).with("/dev/sdb").and_return(@volume)
    end
    @server.should_receive(:id).and_return("i-ephemeral")
    @server.should_receive(:name).exactly(2).and_return("i-ephemeral")
    @volume.should_receive(:id).and_return("volume-ephemeral")
    @registry.should_receive(:read_settings).with("i-ephemeral").and_return(@ephemeral_settings)
    cloud.should_receive(:detach_volume).with(@server, @volume)
    cloud.should_receive(:delete_disk).with("volume-ephemeral")
    @server.should_receive(:destroy).and_return(@job)
    cloud.should_receive(:wait_job).with(@job)
    @registry.should_receive(:delete_settings).with("i-ephemeral")

    cloud.delete_vm("i-ephemeral")
  end

  it "deletes an CloudStack server and an already detached ephemeral disk" do
    cloud = mock_cloud do |compute|
      compute.servers.should_receive(:get).with("i-detached_ephemeral").and_return(@server)
      compute.volumes.should_receive(:get).with("/dev/sdb").and_return(@volume)
    end
    @server.should_receive(:id).and_return("i-detached_ephemeral")
    @server.should_receive(:name).exactly(2).and_return("i-detached_ephemeral")
    @volume.should_receive(:id).and_return("volume-detached_ephemeral")
    @registry.should_receive(:read_settings).with("i-detached_ephemeral").and_return(@ephemeral_settings)
    cloud.should_receive(:detach_volume).with(@server, @volume).and_raise(Bosh::Clouds::CloudError)
    cloud.should_receive(:delete_disk).with("volume-detached_ephemeral")
    @server.should_receive(:destroy).and_return(@job)
    cloud.should_receive(:wait_job).with(@job)
    @registry.should_receive(:delete_settings).with("i-detached_ephemeral")

    cloud.delete_vm("i-detached_ephemeral")
  end

end
