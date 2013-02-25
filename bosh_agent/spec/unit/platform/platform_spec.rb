# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../../spec_helper'

module Bosh::Agent
    class Platform::Linux
      attr_reader :disk, :network
    end
end

describe Bosh::Agent::Platform::Linux do
  let(:platform) do
    Bosh::Agent::Config.platform_name = detect_platform

    if Bosh::Agent::Config.platform_name == "unknown"
      pending("Do Not test unknown platform")
    end

    Bosh::Agent::Config.platform
  end

  context "Disk" do
    it "should detect block device" do
      # Assume rescan_scsi_bus is working on every OS
      platform.disk.stub(:rescan_scsi_bus)

      block_device = platform.disk.detect_block_device(0)

      File.stat("/dev/#{block_device}").ftype.should == "blockSpecial"
    end
  end

end
