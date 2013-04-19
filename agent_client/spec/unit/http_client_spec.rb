require "spec_helper"

describe Bosh::Agent::HTTPClient do

  before(:each) do
    @httpclient = mock("httpclient")
    @httpclient.stub(:ssl_config).and_return(mock("sslconfig").as_null_object)
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

      @httpclient.should_receive(:set_auth).with("https://localhost", "john", "smith")
      @httpclient.should_receive(:request).and_return(response)

      @client = Bosh::Agent::HTTPClient.new("https://localhost",
                                            {"user" => "john",
                                             "password" => "smith"})
      @client.ping
    end

    it "should encode arguments" do
      response = mock("response")
      response.stub!(:code).and_return(200)
      response.stub!(:body).and_return('{"value": "iam"}')

      [:send_timeout=, :receive_timeout=, :connect_timeout=].each do |method|
        @httpclient.should_receive(method)
      end

      headers = {"Content-Type" => "application/json"}
      payload = '{"method":"shh","arguments":["hunting","wabbits"],"reply_to":"elmer"}'

      @httpclient.should_receive(:request).with(:post, "https://localhost/agent",
                                                :body => payload, :header => headers).and_return(response)

      @client = Bosh::Agent::HTTPClient.new("https://localhost", {"reply_to" => "elmer"})

      @client.shh("hunting", "wabbits").should == "iam"
    end

    it "should receive a message value" do
      response = mock("response")
      response.stub!(:code).and_return(200)
      response.stub!(:body).and_return('{"value": "pong"}')

      [:send_timeout=, :receive_timeout=, :connect_timeout=].each do |method|
        @httpclient.should_receive(method)
      end

      headers = {"Content-Type" => "application/json"}
      payload = '{"method":"ping","arguments":[],"reply_to":"fudd"}'

      @httpclient.should_receive(:request).with(:post, "https://localhost/agent",
                                                :body => payload, :header => headers).and_return(response)

      @client = Bosh::Agent::HTTPClient.new("https://localhost", {"reply_to" => "fudd"})

      @client.ping.should == "pong"
    end

    it "should run_task" do
      response = mock("response")
      response.stub!(:code).and_return(200)
      response.stub!(:body).and_return('{"value": {"state": "running", "agent_task_id": "task_id_foo"}}')

      [:send_timeout=, :receive_timeout=, :connect_timeout=].each do |method|
        @httpclient.should_receive(method)
      end

      headers = {"Content-Type" => "application/json"}
      payload = '{"method":"compile_package","arguments":["id","sha1"],"reply_to":"bugs"}'

      @httpclient.should_receive(:request).with(:post, "https://localhost/agent",
                                                :body => payload, :header => headers).and_return(response)

      response2 = mock("response2")
      response2.stub!(:code).and_return(200)
      response2.stub!(:body).and_return('{"value": {"state": "done"}')

      payload = '{"method":"get_task","arguments":["task_id_foo"],"reply_to":"bugs"}'

      [:send_timeout=, :receive_timeout=, :connect_timeout=].each do |method|
        @httpclient.should_receive(method)
      end

      @httpclient.should_receive(:request).with(:post, "https://localhost/agent",
                                                :body => payload, :header => headers).and_return(response2)

      @client = Bosh::Agent::HTTPClient.new("https://localhost", {"reply_to" => "bugs"})

      @client.run_task(:compile_package, "id", "sha1").should == {"state" => "done"}
    end

    it "should raise handler exception when method is invalid" do
      response = mock("response")
      response.stub!(:code).and_return(200)
      response.stub!(:body).and_return('{"exception": "no such method"}')

      [:send_timeout=, :receive_timeout=, :connect_timeout=].each do |method|
        @httpclient.should_receive(method)
      end

      @httpclient.should_receive(:request).and_return(response)

      @client = Bosh::Agent::HTTPClient.new("https://localhost")

      lambda { @client.no_such_method }.should raise_error(Bosh::Agent::HandlerError)

    end

    it "should raise authentication exception when 401 is returned" do
      response = mock("response")
      response.stub!(:code).and_return(401)

      [:send_timeout=, :receive_timeout=, :connect_timeout=].each do |method|
        @httpclient.should_receive(method)
      end

      @httpclient.should_receive(:request).and_return(response)

      @client = Bosh::Agent::HTTPClient.new("https://localhost")

      lambda { @client.ping }.should raise_error(Bosh::Agent::AuthError)
    end
  end

  describe "making a request" do
    describe "error handling" do
      it "should raise an error specifying the type of error and details of the failed request" do
        @client = Bosh::Agent::HTTPClient.new(
            "base_uri",
            {'user' => 'yooser', 'password' => '90553076'}
        )

        [:send_timeout=, :receive_timeout=, :connect_timeout=, :set_auth].each do |method|
          @httpclient.stub(method)
        end
        @httpclient.stub(:request).and_raise(ZeroDivisionError, "3.14")


        expect {
          @client.foo("argz")
        }.to raise_error(
                 Bosh::Agent::Error,
                 /base_uri.+foo.+argz.+yooser.+90553076.+ZeroDivisionError: 3\.14/m
             )
      end
    end
  end
end
