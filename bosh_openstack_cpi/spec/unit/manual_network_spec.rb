# Copyright (c) 2009-2013 VMware, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::ManualNetwork do
  it "should set the IP in manual networking" do
    network_spec = manual_network_spec
    network_spec["ip"] = "172.20.214.10"
    mn = Bosh::OpenStackCloud::ManualNetwork.new("default", network_spec)

    mn.private_ip.should == "172.20.214.10"
  end
end