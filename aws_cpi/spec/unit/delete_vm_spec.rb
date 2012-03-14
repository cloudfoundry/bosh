# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AWSCloud::Cloud do
  describe "#delete_vm" do
    it "should delete a vm" do
      instance_id = "foo"
      cloud = make_mock_cloud(mock_cloud_options) do |ec2|
        instance = double("instance")
        instance.should_receive(:status).and_return(:running, :terminated)
        instance.stub(:id).and_return("id")
        instance.should_receive(:terminate).and_return(instance)
        ec2.instances.should_receive(:[]).with(instance_id).and_return(instance)
      end
      cloud.delete_vm(instance_id)
    end
  end
end
