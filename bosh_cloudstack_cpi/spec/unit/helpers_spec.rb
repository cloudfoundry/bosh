# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::CloudStackCloud::Helpers do
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
        @cloud.wait_resource(resource, :stop, :status, false)
      }.to raise_error Bosh::Clouds::CloudError, /Timed out/
    end

    it "should not time out" do
      resource = double("resource")
      resource.stub(:id).and_return("foobar")
      resource.stub(:reload).and_return(@cloud)
      resource.stub(:status).and_return(:start, :stop)
      @cloud.stub(:sleep)

      @cloud.wait_resource(resource, :stop, :status, false)
    end

    it "should accept an Array of target states" do
      resource = double("resource")
      resource.stub(:id).and_return("foobar")
      resource.stub(:reload).and_return(@cloud)
      resource.stub(:status).and_return(:start, :stop)
      @cloud.stub(:sleep)

      @cloud.wait_resource(resource, [:stop, :deleted], :status, false)
    end

    it "should raise Bosh::Clouds::CloudError if state is error" do
      resource = double("resource")
      resource.stub(:id).and_return("foobar")
      resource.stub(:reload).and_return(@cloud)
      resource.stub(:status).and_return(:error)
      @cloud.stub(:sleep)

      expect {
        @cloud.wait_resource(resource, :stop, :status, false)
      }.to raise_error Bosh::Clouds::CloudError, /state is error/
    end

    it "should raise Bosh::Clouds::CloudError if state is failed" do
      resource = double("resource")
      resource.stub(:id).and_return("foobar")
      resource.stub(:reload).and_return(@cloud)
      resource.stub(:status).and_return(:failed)
      @cloud.stub(:sleep)

      expect {
        @cloud.wait_resource(resource, :stop, :status, false)
      }.to raise_error Bosh::Clouds::CloudError, /state is failed/
    end

    it "should raise Bosh::Clouds::CloudError if state is killed" do
      resource = double("resource")
      resource.stub(:id).and_return("foobar")
      resource.stub(:reload).and_return(@cloud)
      resource.stub(:status).and_return(:killed)
      @cloud.stub(:sleep)

      expect {
        @cloud.wait_resource(resource, :stop, :status, false)
      }.to raise_error Bosh::Clouds::CloudError, /state is killed/
    end

    it "should raise Bosh::Clouds::CloudError if resource not found" do
      resource = double("resource")
      resource.stub(:id).and_return("foobar")
      resource.stub(:reload).and_return(nil)
      @cloud.stub(:sleep)

      expect {
        @cloud.wait_resource(resource, :deleted, :status, false)
      }.to raise_error Bosh::Clouds::CloudError, /Resource not found/
    end

    it "should not raise and exception if resource not found" do
      resource = double("resource")
      resource.stub(:id).and_return("foobar")
      resource.stub(:reload).and_return(nil)
      resource.stub(:status).and_return(:deleted)
      @cloud.stub(:sleep)

      @cloud.wait_resource(resource, :deleted, :status, true)
    end
  end

  describe "with_compute" do
    before(:each) do
      @compute = double("openstack")
    end

    it "should raise the exception if not a rescued exception" do
      response = Excon::Response.new(:body => "")

      @compute.should_receive(:servers)
        .and_raise(NoMemoryError)
      @cloud.should_not_receive(:sleep)

      expect {
        @cloud.with_compute do
          @compute.servers
        end
      }.to raise_error(NoMemoryError)
    end

    context "BadRequest" do
      it "should raise a CloudError exception with CloudStack API message if there is a BadRequest" do
        message = "Invalid volume: Volume still has 1 dependent snapshots"
        response = Excon::Response.new(:body => JSON.dump({"badRequest" => {"message" => message}}))
        @compute.should_receive(:servers).and_raise(Excon::Errors::BadRequest.new("", "", response))

        expect {
          @cloud.with_compute do
            @compute.servers
          end
        }.to raise_error(Bosh::Clouds::CloudError,
                         "CloudStack API Bad Request (#{message}). Check task debug log for details.")
      end

      it "should raise a CloudError exception without CloudStack API message if there is a BadRequest" do
        response = Excon::Response.new(:body => "")
        @compute.should_receive(:servers).and_raise(Excon::Errors::BadRequest.new("", "", response))

        expect {
          @cloud.with_compute do
            @compute.servers
          end
        }.to raise_error(Bosh::Clouds::CloudError,
                         "CloudStack API Bad Request. Check task debug log for details.")
      end
    end

    context "InternalServerError" do
      it "should retry the max number of retries before raising a CloudError exception" do
        @compute.should_receive(:servers).exactly(11)
          .and_raise(Excon::Errors::InternalServerError.new("InternalServerError"))
        @cloud.should_receive(:sleep).with(3).exactly(10)

        expect {
          @cloud.with_compute do
            @compute.servers
          end
        }.to raise_error(Bosh::Clouds::CloudError,
                         "CloudStack API Internal Server error. Check task debug log for details.")
      end
    end
  end

  describe "parse_api_response" do
    it "should return nil if response has no body" do
      response = Excon::Response.new()

      expect(@cloud.parse_api_response(response, "key")).to be_nil
    end

    it "should return nil if response has an empty body" do
      response = Excon::Response.new(:body => JSON.dump(""))

      expect(@cloud.parse_api_response(response, "key")).to be_nil
    end

    it "should return nil if response is not JSON" do
      response = Excon::Response.new(:body => "foo = bar")

      expect(@cloud.parse_api_response(response, "key")).to be_nil
    end

    it "should return nil if response is no key is found" do
      response = Excon::Response.new(:body => JSON.dump({"foo" => "bar"}))

      expect(@cloud.parse_api_response(response, "key")).to be_nil
    end

    it "should return the contents if key is found" do
      response = Excon::Response.new(:body => JSON.dump({"key" => "foo"}))

      expect(@cloud.parse_api_response(response, "key")).to eql("foo")
    end

    it "should return the contents of the first key found" do
      response = Excon::Response.new(:body => JSON.dump({"key1" => "foo", "key2" => "bar"}))

      expect(@cloud.parse_api_response(response, "key2", "key1")).to eql("bar")
    end
  end
end
