# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Helpers do
  before(:each) do
    @cloud = mock_cloud
    Bosh::Clouds::Config.stub(:task_checkpoint)
  end

  describe "wait_resource" do
    it "should time out" do
      resource = double("resource")
      resource.stub(:id).and_return("foobar")
      resource.stub(:reload).and_return(@cloud)
      resource.stub(:status).and_return(:start)
      @cloud.stub(:sleep)

      expect {
        @cloud.wait_resource(resource, :stop, :status, false, 0.1)
      }.to raise_error Bosh::Clouds::CloudError, /Timed out/
    end

    it "should not time out" do
      resource = double("resource")
      resource.stub(:id).and_return("foobar")
      resource.stub(:reload).and_return(@cloud)
      resource.stub(:status).and_return(:start, :stop)
      @cloud.stub(:sleep)

      @cloud.wait_resource(resource, :stop, :status, false, 0.1)
    end

    it "should accept an Array of target states" do
      resource = double("resource")
      resource.stub(:id).and_return("foobar")
      resource.stub(:reload).and_return(@cloud)
      resource.stub(:status).and_return(:start, :stop)
      @cloud.stub(:sleep)

      @cloud.wait_resource(resource, [:stop, :deleted], :status, false, 0.1)
    end

    it "should raise Bosh::Clouds::CloudError if state is error" do
      resource = double("resource")
      resource.stub(:id).and_return("foobar")
      resource.stub(:reload).and_return(@cloud)
      resource.stub(:status).and_return(:error)
      @cloud.stub(:sleep)

      expect {
        @cloud.wait_resource(resource, :stop, :status, false, 0.1)
      }.to raise_error Bosh::Clouds::CloudError, /state is error/
    end

    it "should raise Bosh::Clouds::CloudError if resource not found" do
      resource = double("resource")
      resource.stub(:id).and_return("foobar")
      resource.stub(:reload).and_return(nil)
      @cloud.stub(:sleep)

      expect {
        @cloud.wait_resource(resource, :deleted, :status, false, 0.1)
      }.to raise_error Bosh::Clouds::CloudError, /Resource not found/
    end

    it "should not raise and exception if resource not found" do
      resource = double("resource")
      resource.stub(:id).and_return("foobar")
      resource.stub(:reload).and_return(nil)
      resource.stub(:status).and_return(:deleted)
      @cloud.stub(:sleep)

      @cloud.wait_resource(resource, :deleted, :status, true, 0.1)
    end
  end

  describe "with_openstack" do
    before(:each) do
      @openstack = double("openstack")
    end

    it "should raise the exception if not RequestEntityTooLarge exception" do
      response = Excon::Response.new(:body => "")

      @openstack.should_receive(:servers)
        .and_raise(Bosh::Clouds::CloudError)
      @cloud.should_not_receive(:sleep)

      expect {
        @cloud.with_openstack do
          @openstack.servers
        end
      }.to raise_error(Bosh::Clouds::CloudError)
    end

    it "should raise the exception if response has no body" do
      response = Excon::Response.new(:body => "")

      @openstack.should_receive(:servers)
        .and_raise(Excon::Errors::RequestEntityTooLarge.new("", "", response))
      @cloud.should_not_receive(:sleep)

      expect {
        @cloud.with_openstack do
          @openstack.servers
        end
      }.to raise_error(Excon::Errors::RequestEntityTooLarge)
    end

    it "should raise the exception if response is not JSON" do
      response = Excon::Response.new(:body => "foo = bar")

      @openstack.should_receive(:servers)
        .and_raise(Excon::Errors::RequestEntityTooLarge.new("", "", response))
      @cloud.should_not_receive(:sleep)

      expect {
        @cloud.with_openstack do
          @openstack.servers
        end
      }.to raise_error(Excon::Errors::RequestEntityTooLarge)
    end

    it "should retry the amount of seconds received at the response body" do
      body = { "overLimit" => {
          "message" => "This request was rate-limited.",
          "code" => 413,
          "retryAfter" => "5",
          "details" => "Only 10 POST request(s) can be made to * every minute."}
      }
      response = Excon::Response.new(:body => JSON.dump(body))

      @openstack.should_receive(:servers)
        .and_raise(Excon::Errors::RequestEntityTooLarge.new("", "", response))
      @cloud.should_receive(:sleep).with(5)
      @openstack.should_receive(:servers).and_return(nil)

      @cloud.with_openstack do
        @openstack.servers
      end
    end

    it "should retry the default number of seconds if not set at the response body" do
      body = { "overLimitFault" => {
          "message" => "This request was rate-limited.",
          "code" => 413,
          "details" => "Only 10 POST request(s) can be made to * every minute."}
      }
      response = Excon::Response.new(:body => JSON.dump(body))

      @openstack.should_receive(:servers)
        .and_raise(Excon::Errors::RequestEntityTooLarge.new("", "", response))
      @cloud.should_receive(:sleep).with(1)
      @openstack.should_receive(:servers).and_return(nil)

      @cloud.with_openstack do
        @openstack.servers
      end
    end

    it "should retry the max number of retries" do
      body = { "overLimit" => {
          "message" => "This request was rate-limited.",
          "code" => 413,
          "retryAfter" => "5",
          "details" => "Only 10 POST request(s) can be made to * every minute."}
      }
      response = Excon::Response.new(:body => JSON.dump(body))

      @openstack.should_receive(:servers).exactly(11)
        .and_raise(Excon::Errors::RequestEntityTooLarge.new("", "", response))
      @cloud.should_receive(:sleep).with(5).exactly(10)

      expect {
        @cloud.with_openstack do
          @openstack.servers
        end
      }.to raise_error(Excon::Errors::RequestEntityTooLarge)
    end
  end
end
