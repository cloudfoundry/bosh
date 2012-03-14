# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AWSCloud::Helpers do
  it "should time out" do
    cloud = make_mock_cloud

    resource = double("resource")
    resource.stub(:status).and_return(:start)

    lambda {
      cloud.wait_resource(resource, :start, :stop, :status, 1)
    }.should raise_error Bosh::Clouds::CloudError
  end

  it "should not time out" do
    cloud = make_mock_cloud

    resource = double("resource")
    resource.stub(:status).and_return(:start, :stop)

    lambda {
      cloud.wait_resource(resource, :start, :stop, :status, 1)
    }.should_not raise_error Bosh::Clouds::CloudError
  end

  it "should raise error when target state is wrong" do
    cloud = make_mock_cloud

    resource = double("resource")
    resource.stub(:status).and_return(:started, :failed)

    lambda {
      cloud.wait_resource(resource, :started, :stopped, :status, 1)
    }.should raise_error Bosh::Clouds::CloudError,
      /is failed, expected to be stopped/
  end
end
