# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::AwsCloud::Cloud, "create_vm" do

  it "should create an EC2 instance" do
    instance_manager = double("InstanceManager")
    instance_manager.should_receive(:create).with("agent_id", "stemcell_id", "resource_pool", "network_spec", "disk_locality", "environment", mock_cloud_options)

    registry = mock_registry
    region = nil
    az_selector = nil
    ec2 = mock_cloud do |ec2, r|
      region = r
      az_selector = double("az_selector")
    end
    ec2.stub(:az_selector => az_selector)

    Bosh::AwsCloud::InstanceManager.should_receive(:new).with(region, registry, az_selector).and_return(instance_manager)

    ec2.create_vm("agent_id", "stemcell_id", "resource_pool", "network_spec", "disk_locality", "environment")
  end

end
