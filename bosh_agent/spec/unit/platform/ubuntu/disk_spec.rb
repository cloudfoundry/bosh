# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'
require 'bosh_agent/platform/ubuntu/disk'

describe Bosh::Agent::Platform::Ubuntu::Disk do

  let(:disk) { Bosh::Agent::Platform::Ubuntu::Disk.new }

  it "detects block device with scsi rescan" do
    disk.should_receive(:rescan_scsi_bus)
    disk_id = "disk-id"
    Dir.should_receive(:glob).with("/sys/bus/scsi/devices/2:0:#{disk_id}:0/block/*", 0).and_return(["/dev/block:something", "/dev/something-else"])
    Dir.should_receive(:glob).with("/sys/bus/scsi/devices/2:0:#{disk_id}:0/block/*", 0).and_return(["/dev/block:something", "/dev/something-else"])

    disk.detect_block_device(disk_id).should eq "block:something"
  end

end
