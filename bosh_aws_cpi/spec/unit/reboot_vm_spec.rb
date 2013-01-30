# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AwsCloud::Cloud do

  describe "#reboot_vm" do
    let(:fake_instance_id) {"i-xxxxxxxx"}

    it "should reboot an instance given the id" do
      cloud = mock_cloud(mock_cloud_options)
      im = double(Bosh::AwsCloud::InstanceManager)
      im.should_receive(:reboot).with(fake_instance_id)
      Bosh::AwsCloud::InstanceManager.stub(:new).and_return(im)
      cloud.reboot_vm(fake_instance_id)
    end
  end
end
