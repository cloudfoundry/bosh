# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Helpers do
  before(:each) do
    Bosh::Clouds::Config.stub(:task_checkpoint)
  end

  it "should time out" do
    cloud = mock_cloud

    resource = double("resource")
    resource.stub(:id).and_return("foobar")
    resource.stub(:reload).and_return(cloud)
    resource.stub(:status).and_return(:start)
    cloud.stub(:sleep)

    expect {
      cloud.wait_resource(resource, :stop, :status, false, 0.1)
    }.to raise_error Bosh::Clouds::CloudError, /Timed out/
  end

  it "should not time out" do
    cloud = mock_cloud

    resource = double("resource")
    resource.stub(:id).and_return("foobar")
    resource.stub(:reload).and_return(cloud)
    resource.stub(:status).and_return(:start, :stop)
    cloud.stub(:sleep)

    cloud.wait_resource(resource, :stop, :status, false, 0.1)
  end

  it "should raise Bosh::Clouds::CloudError if state is error" do
    cloud = mock_cloud

    resource = double("resource")
    resource.stub(:id).and_return("foobar")
    resource.stub(:reload).and_return(cloud)
    resource.stub(:status).and_return(:error)
    cloud.stub(:sleep)

    expect {
      cloud.wait_resource(resource, :stop, :status, false, 0.1)
    }.to raise_error Bosh::Clouds::CloudError, /state is error/
  end

  it "should raise Bosh::Clouds::CloudError if resource not found" do
    cloud = mock_cloud

    resource = double("resource")
    resource.stub(:id).and_return("foobar")
    resource.stub(:reload).and_return(nil)
    cloud.stub(:sleep)

    expect {
      cloud.wait_resource(resource, :deleted, :status, false, 0.1)
    }.to raise_error Bosh::Clouds::CloudError, /Resource not found/
  end

  it "should not raise and exception if resource not found" do
    cloud = mock_cloud

    resource = double("resource")
    resource.stub(:id).and_return("foobar")
    resource.stub(:reload).and_return(nil)
    resource.stub(:status).and_return(:deleted)
    cloud.stub(:sleep)

    cloud.wait_resource(resource, :deleted, :status, true, 0.1)
  end
end
