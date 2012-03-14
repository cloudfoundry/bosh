# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AWSCloud::Cloud do
  describe "#delete_vm" do
    it "should delete a vm" do
      rc = double(Bosh::AWSCloud::RegistryClient)
      rc.stub(:endpoint).and_return("endpoint")
      rc.stub(:delete_settings)
      Bosh::AWSCloud::RegistryClient.should_receive(:new).and_return(rc)

      instance_id = "foo"
      cloud = make_mock_cloud(mock_cloud_options) do |ec2|
        instance = double("instance")
        instance.should_receive(:status).and_return(:running, :terminated)
        instance.stub(:id).and_return("id")
        instance.stub(:private_ip_address)
        instance.should_receive(:terminate).and_return(instance)
        ec2.instances.should_receive(:[]).with(instance_id).and_return(instance)
      end
      cloud.delete_vm(instance_id)
    end
  end
end
