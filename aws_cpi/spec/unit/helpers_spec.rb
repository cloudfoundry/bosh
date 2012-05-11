# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AwsCloud::Helpers do
  it "should time out" do
    cloud = mock_cloud

    resource = double("resource")
    resource.stub(:status).and_return(:start)
    cloud.stub(:sleep)

    lambda {
      cloud.wait_resource(resource, :stop, :status, 0.1)
    }.should raise_error Bosh::Clouds::CloudError, /Timed out/
  end

  it "should not time out" do
    cloud = mock_cloud

    resource = double("resource")
    resource.stub(:status).and_return(:start, :stopping, :stopping, :stop)
    cloud.stub(:sleep)

    lambda {
      cloud.wait_resource(resource, :stop, :status, 0.1)
    }.should_not raise_error Bosh::Clouds::CloudError
  end

  it "should raise error when target state is wrong" do
    cloud = mock_cloud

    resource = double("resource")
    resource.stub(:status).and_return(:started, :failed)
    cloud.stub(:sleep)

    lambda {
      cloud.wait_resource(resource, :stopped, :status, 0.1)
    }.should raise_error Bosh::Clouds::CloudError,
                         /is failed, expected stopped/
  end
end
