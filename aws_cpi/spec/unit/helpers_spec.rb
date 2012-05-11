# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AwsCloud::Helpers do
  it "should time out" do
    cloud = mock_cloud

    resource = double("resource")
    resource.stub(:status).and_return(:start)
    cloud.stub(:sleep)

    lambda {
      cloud.wait_resource(resource, :start, :stop, :status, 0.1)
    }.should raise_error Bosh::Clouds::CloudError, /Timed out/
  end

  it "should not time out" do
    cloud = mock_cloud

    resource = double("resource")
    resource.stub(:status).and_return(:start, :stop)
    cloud.stub(:sleep)

    lambda {
      cloud.wait_resource(resource, :start, :stop, :status, 0.1)
    }.should_not raise_error Bosh::Clouds::CloudError
  end

  it "should raise error when target state is wrong" do
    cloud = mock_cloud

    resource = double("resource")
    resource.stub(:status).and_return(:started, :failed)
    cloud.stub(:sleep)

    lambda {
      cloud.wait_resource(resource, :started, :stopped, :status, 0.1)
    }.should raise_error Bosh::Clouds::CloudError,
                         /is failed, expected to be stopped/
  end

  describe "#get_availability_zone" do
    def volume(zone)
      vol = double("volume")
      vol.stub(:availability_zone).and_return(zone)
      vol
    end

    describe "with no availability_zone configured in the resource_pool" do
      it "should not raise an error when the zones are the same" do
        cloud = mock_cloud do |ec2|
          ec2.volumes.stub(:[]).and_return(volume("foo"), volume("foo"))
        end
        cloud.get_availability_zone(%w[cid1 cid2], nil)
      end

      it "should raise an error when the zones differ" do
        cloud = mock_cloud do |ec2|
          ec2.volumes.stub(:[]).and_return(volume("foo"), volume("bar"))
        end
        lambda {
          cloud.get_availability_zone(%w[cid1 cid2], nil)
        }.should raise_error "can't use multiple availability zones"
      end
    end

    describe "with availability_zone configured in the resource_pool" do
      it "should not raise an error when the zones are the same" do
        cloud = mock_cloud do |ec2|
          ec2.volumes.stub(:[]).and_return(volume("foo"), volume("foo"))
        end
        cloud.get_availability_zone(%w[cid1 cid2], "foo")
      end

      it "should raise an error when the zones differ" do
        cloud = mock_cloud do |ec2|
          ec2.volumes.stub(:[]).and_return(volume("foo"), volume("foo"))
        end
        lambda {
          cloud.get_availability_zone(%w[cid1 cid2], "bar")
        }.should raise_error "can't use multiple availability zones"
      end
    end

  end
end
