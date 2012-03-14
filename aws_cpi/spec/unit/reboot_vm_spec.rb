# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AWSCloud::Cloud do
  describe "#reboot_vm" do
    it "should reboot a vm" do
      instance_id = "foo"
      cloud = make_mock_cloud(mock_cloud_options) do |ec2|
        instance = double("instance")
        instance.should_receive(:status).
          and_return(:running, :stopped, :stopped, :running)
        instance.stub(:id).and_return("id")

        instance.should_receive(:stop)
        instance.should_receive(:start)

        ec2.instances.should_receive(:[]).with(instance_id).and_return(instance)
      end
      cloud.reboot_vm(instance_id)
    end
  end
end
