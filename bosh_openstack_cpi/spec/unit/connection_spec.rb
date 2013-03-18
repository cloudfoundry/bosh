# Copyright (c) 2009-2013 VMware, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Connection do
  before(:each) do
    Bosh::Clouds::Config.stub(:task_checkpoint)
  end

  describe "Compute service" do
    before(:each) do
      @fog_compute = double(Fog::Compute)
      Fog::Compute.stub(:new).and_return(@fog_compute)
      @connection = Bosh::OpenStackCloud::Connection.new(:compute, {})
    end

    it "should respond to a Fog::Compute method" do
      @fog_compute.should_receive(:respond_to?).with(:servers).and_return(true)
      @fog_compute.should_receive(:servers)

      @connection.servers
    end

    it "should raise an error if Fog::Compute doesn't respond to a method" do
      @fog_compute.should_receive(:respond_to?).with(:pair).and_return(false)

      expect {
        @connection.pair
      }.to raise_error(NoMethodError, /undefined method `pair' for/)
    end
  end

  describe "Image service" do
    before(:each) do
      @fog_image = double(Fog::Image)
      Fog::Image.stub(:new).and_return(@fog_image)
      @connection = Bosh::OpenStackCloud::Connection.new(:image, {})
    end

    it "should respond to a Fog::Image method" do
      @fog_image.should_receive(:respond_to?).with(:images).and_return(true)
      @fog_image.should_receive(:images)

      @connection.images
    end

    it "should raise an error if Fog::Image doesn't respond to a method" do
      @fog_image.should_receive(:respond_to?).with(:pair).and_return(false)

      expect {
        @connection.pair
      }.to raise_error(NoMethodError, /undefined method `pair' for/)
    end
  end

  describe "Unknow service" do
    it "should raise an unsupported service error" do
      expect {
        Bosh::OpenStackCloud::Connection.new(:pair, {})
      }.to raise_error(Bosh::Clouds::CloudError, /Service pair not supported by OpenStack CPI/)
    end
  end

  describe "RequestEntityTooLarge exception" do
    before(:each) do
      @fog_compute = double(Fog::Compute)
      Fog::Compute.stub(:new).and_return(@fog_compute)
      @connection = Bosh::OpenStackCloud::Connection.new(:compute, {})
    end

    it "should retry after the amount of seconds received at the response body" do
      body = { "overLimit" => {
                 "message" => "This request was rate-limited.",
                 "code" => 413,
                 "retryAfter" => "1",
                 "details" => "Only 10 POST request(s) can be made to * every minute."}
             }
      response = Excon::Response.new(:body => JSON.dump(body))

      @fog_compute.should_receive(:respond_to?).with(:servers).and_return(true)
      @fog_compute.should_receive(:servers).
        and_raise(Excon::Errors::RequestEntityTooLarge.new("", "", response))
      @connection.should_receive(:sleep).with(1)
      @fog_compute.should_receive(:servers)

      @connection.servers
    end

    it "should retry after the max number of seconds before retrying a call" do
      body = { "overLimit" => {
                 "message" => "This request was rate-limited.",
                 "code" => 413,
                 "retryAfter" => "20",
                 "details" => "Only 10 POST request(s) can be made to * every minute."}
             }
      response = Excon::Response.new(:body => JSON.dump(body))

      @fog_compute.should_receive(:respond_to?).with(:servers).and_return(true)
      @fog_compute.should_receive(:servers).
        and_raise(Excon::Errors::RequestEntityTooLarge.new("", "", response))
      @connection.should_receive(:sleep).with(10)
      @fog_compute.should_receive(:servers)

      @connection.servers
    end

    it "should raise an error if response has no body" do
      response = Excon::Response.new(:body => "")

      @fog_compute.should_receive(:respond_to?).with(:servers).and_return(true)
      @fog_compute.should_receive(:servers).
        and_raise(Excon::Errors::RequestEntityTooLarge.new("", "", response))

      expect {
        @connection.servers
      }.to raise_error(Excon::Errors::RequestEntityTooLarge)
    end

    it "should raise an error if response has no overlimit message" do
      body = "This request was rate-limited."
      response = Excon::Response.new(:body => JSON.dump(body))

      @fog_compute.should_receive(:respond_to?).with(:servers).and_return(true)
      @fog_compute.should_receive(:servers).
        and_raise(Excon::Errors::RequestEntityTooLarge.new("", "", response))

      expect {
        @connection.servers
      }.to raise_error(Excon::Errors::RequestEntityTooLarge)
    end
  end
end
