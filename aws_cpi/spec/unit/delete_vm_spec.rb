# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AwsCloud::Cloud do

  before(:each) do
    @registry = mock_registry
  end

  it "deletes an EC2 instance" do
    instance = double("instance", :id => "i-foobar")

    cloud = mock_cloud do |ec2|
      ec2.instances.stub(:[]).with("i-foobar").and_return(instance)
    end

    instance.should_receive(:terminate)
    cloud.should_receive(:wait_resource).with(instance, :terminated)

    @registry.should_receive(:delete_settings).with("i-foobar")

    cloud.delete_vm("i-foobar")
  end
end
