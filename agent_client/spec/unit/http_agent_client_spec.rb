require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Agent::HTTPClient do

  before(:each) do
    @httpclient = mock("httpclient")
    HTTPClient.stub!(:new).and_return(@httpclient)
  end

  describe "options" do

    it "should set up authentication when present" do
      response = mock("response")
      response.stub!(:code).and_return(200)
      response.stub!(:body).and_return('{"value": "pong"}')

      [:send_timeout=, :receive_timeout=, :connect_timeout=].each do |method|
        @httpclient.should_receive(method)
      end

      @httpclient.should_receive(:set_auth).with("http://localhost", "john", "smith")
      @httpclient.should_receive(:request).and_return(response)

      @client = Bosh::Agent::HTTPClient.new("http://localhost",
                                            { "user" => "john",
                                              "password" => "smith" })
      @client.ping
    end

    it "should encode arguments" do
      response = mock("response")
      response.stub!(:code).and_return(200)
      response.stub!(:body).and_return('{"value": "iam"}')

      [:send_timeout=, :receive_timeout=, :connect_timeout=].each do |method|
        @httpclient.should_receive(method)
      end

      headers = { "Content-Type" => "application/json" }
      payload = '{"method":"shh","arguments":["hunting","wabbits"]}'

      @httpclient.should_receive(:request).with(:post, "http://localhost/agent",
                                                :body => payload, :header => headers).and_return(response)

      @client = Bosh::Agent::HTTPClient.new("http://localhost")

      @client.shh("hunting", "wabbits").should == "iam"
    end

    it "should receive a message value" do
      response = mock("response")
      response.stub!(:code).and_return(200)
      response.stub!(:body).and_return('{"value": "pong"}')

      [:send_timeout=, :receive_timeout=, :connect_timeout=].each do |method|
        @httpclient.should_receive(method)
      end

      headers = { "Content-Type" => "application/json" }
      payload = '{"method":"ping","arguments":[]}'

      @httpclient.should_receive(:request).with(:post, "http://localhost/agent",
                                                :body => payload, :header => headers).and_return(response)

      @client = Bosh::Agent::HTTPClient.new("http://localhost")

      @client.ping.should == "pong"
    end

    it "should run_task" do
      response = mock("response")
      response.stub!(:code).and_return(200)
      response.stub!(:body).and_return('{"value": {"state": "running", "agent_task_id": "task_id_foo"}}')

      [:send_timeout=, :receive_timeout=, :connect_timeout=].each do |method|
        @httpclient.should_receive(method)
      end

      headers = { "Content-Type" => "application/json" }
      payload = '{"method":"compile_package","arguments":["id","sha1"]}'

      @httpclient.should_receive(:request).with(:post, "http://localhost/agent",
                                                :body => payload, :header => headers).and_return(response)

      response2 = mock("response2")
      response2.stub!(:code).and_return(200)
      response2.stub!(:body).and_return('{"value": {"state": "done"}')

      payload = '{"method":"get_task","arguments":["task_id_foo"]}'

      [:send_timeout=, :receive_timeout=, :connect_timeout=].each do |method|
        @httpclient.should_receive(method)
      end

      @httpclient.should_receive(:request).with(:post, "http://localhost/agent",
                                                :body => payload, :header => headers).and_return(response2)

      @client = Bosh::Agent::HTTPClient.new("http://localhost")

      @client.run_task(:compile_package, "id", "sha1").should == { "state" => "done" }
    end

    it "should raise handler exception when method is invalid" do
      response = mock("response")
      response.stub!(:code).and_return(200)
      response.stub!(:body).and_return('{"exception": "no such method"}')

      [:send_timeout=, :receive_timeout=, :connect_timeout=].each do |method|
        @httpclient.should_receive(method)
      end

      @httpclient.should_receive(:request).and_return(response)

      @client = Bosh::Agent::HTTPClient.new("http://localhost")

      lambda { @client.no_such_method }.should raise_error(Bosh::Agent::HandlerError)

    end

    it "should raise authentication exception when 401 is returned" do
      response = mock("response")
      response.stub!(:code).and_return(401)

      [:send_timeout=, :receive_timeout=, :connect_timeout=].each do |method|
        @httpclient.should_receive(method)
      end

      @httpclient.should_receive(:request).and_return(response)

      @client = Bosh::Agent::HTTPClient.new("http://localhost")

      lambda { @client.ping }.should raise_error(Bosh::Agent::AuthError)
    end
  end
end
