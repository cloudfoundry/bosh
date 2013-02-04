# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::AwsCloud::Cloud, "#set_vm_metadata" do
  let(:instance) { double("instance", :id => "i-foobar") }

  before :each do
    @cloud = mock_cloud(mock_cloud_options) do |ec2|
      ec2.instances.stub(:[]).with("i-foobar").and_return(instance)
    end
  end

  it "should add new tags" do
    metadata = {:job => "job", :index => "index"}

    Bosh::AwsCloud::TagManager.should_receive(:tag).with(instance, :job, "job")
    Bosh::AwsCloud::TagManager.should_receive(:tag).with(instance, :index, "index")
    Bosh::AwsCloud::TagManager.should_receive(:tag).with(instance, "Name", "job/index")

    @cloud.set_vm_metadata("i-foobar", metadata)
  end

end
