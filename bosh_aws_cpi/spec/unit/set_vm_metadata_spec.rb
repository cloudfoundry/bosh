# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::AwsCloud::Cloud, "#set_vm_metadata" do
  before :each do
    @instance = double("instance", :id => "i-foobar")

    @cloud = mock_cloud(mock_cloud_options) do |ec2|
      ec2.instances.stub(:[]).with("i-foobar").and_return(@instance)
    end
  end

  it "should add new tags" do
    metadata = {:job => "job", :index => "index"}
    @cloud.should_receive(:tag).with(@instance, :job, "job")
    @cloud.should_receive(:tag).with(@instance, :index, "index")
    @cloud.should_receive(:tag).with(@instance, "Name", "job/index")
    @cloud.set_vm_metadata("i-foobar", metadata)
  end

  it "should trim key and value length" do
    metadata = {"x"*128 => "y"*256}
    @instance.should_receive(:add_tag) do |key, options|
      key.size.should == 127
      options[:value].size.should == 255
    end
    @cloud.set_vm_metadata("i-foobar", metadata)
  end
end
