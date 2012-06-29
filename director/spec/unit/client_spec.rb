# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::Client do

  before(:each) do
    @nats_rpc = mock(BD::NatsRpc)
    Bosh::Director::Config.stub!(:nats_rpc).and_return(@nats_rpc)
  end

  let(:test_args) do
    ["arg 1", 2, {:test => "blah"}]
  end

  let(:test_rpc_args) do
    @test_rpc_args = {:arguments => test_args, :method => :baz}
  end

  def make(*args)
    BD::Client.new(*args)
  end

  it "should send messages and return values" do
    response = {"value" => 5}

    @nats_rpc.should_receive(:send_request).
      with("foo.bar", test_rpc_args).and_yield(response)

    client = Bosh::Director::Client.new("foo", "bar")
    client.baz(*test_args).should == 5
  end

  it "should handle exceptions" do
    response = {
      "exception" => {
        "message" => "test",
        "backtrace" => %w(a b c),
        "blobstore_id" => "deadbeef"
      }
    }

    @nats_rpc.should_receive(:send_request).
      with("foo.bar", test_rpc_args).and_yield(response)

    rm = mock(Bosh::Director::Api::ResourceManager)
    rm.should_receive(:get_resource).with("deadbeef").and_return("an exception")
    rm.should_receive(:delete_resource).with("deadbeef")
    Bosh::Director::Api::ResourceManager.should_receive(:new).and_return(rm)

    client = make("foo", "bar")
    expected_error_message = "test\na\nb\nc\nan exception"

    lambda {
      client.baz(*test_args)
    }.should raise_exception(BD::RpcRemoteException, expected_error_message)
  end

  describe "timeouts/retries" do
    it "should handle timeouts" do
      @nats_rpc.should_receive(:send_request).
        with("foo.bar", test_rpc_args).and_return("req_id")
      @nats_rpc.should_receive(:cancel_request).with("req_id")

      client = make("foo", "bar", :timeout => 0.1)

      lambda {
        client.baz(*test_args)
      }.should raise_exception(BD::RpcTimeout)
    end

    it "should retry only methods in the options list" do
      client_opts = {
        :timeout => 0.1,
        :retry_methods => {:foo => 10}
      }

      args = {:method => :baz, :arguments => []}

      @nats_rpc.should_receive(:send_request).
        with("foo.bar", args).once.and_raise(BD::RpcTimeout)

      client = make("foo", "bar", client_opts)

      lambda {
        client.baz
      }.should raise_exception(BD::RpcTimeout)
    end

    it "should retry methods" do
      args = {:method => :baz, :arguments => []}

      @nats_rpc.should_receive(:send_request).
        with("foo.bar", args).exactly(2).times.and_raise(BD::RpcTimeout)

      client_opts = {
        :timeout => 0.1,
        :retry_methods => {:baz => 1}
      }

      client = make("foo", "bar", client_opts)

      lambda {
        client.baz
      }.should raise_exception(BD::RpcTimeout)
    end

    it "should retry only timeout errors" do
      args = {:method => :baz, :arguments => []}

      @nats_rpc.should_receive(:send_request).
        with("foo.bar", args).once.and_raise(RuntimeError.new("foo"))

      client_opts = {
        :timeout => 0.1,
        :retry_methods => {:retry_method => 10}
      }

      client = make("foo", "bar", client_opts)

      lambda {
        client.baz
      }.should raise_exception(RuntimeError, "foo")
    end

    it "should let you wait for the server to be ready" do
      @client = make("foo", "bar", :timeout => 0.1)

      @client.should_receive(:ping).and_raise(BD::RpcTimeout)
      @client.should_receive(:ping).and_raise(BD::RpcTimeout)
      @client.should_receive(:ping).and_raise(BD::RpcTimeout)
      @client.should_receive(:ping).and_return(true)

      @client.wait_until_ready
    end
  end


  describe "encryption" do
    it "should encrypt message" do
      credentials = Bosh::EncryptionHandler.generate_credentials
      client_opts = {:timeout => 0.1, :credentials => credentials}
      response = {"value" => 5}

      @nats_rpc.should_receive(:send_request) { |*args, &blk|
        args[0].should == "foo.bar"
        request = args[1]
        data = request["encrypted_data"]

        handler = Bosh::EncryptionHandler.new("bar", credentials)

        message = handler.decrypt(data)
        message["method"].should == "baz"
        message["arguments"].should == [1, 2, 3]
        message["sequence_number"].to_i.should > Time.now.to_i
        message["client_id"].should == "bar"

        # TODO accessor for session_id
        # message["session_id"].should == handler.session_id
        blk.call("encrypted_data" => handler.encrypt(response))
      }

      client = make("foo", "bar", client_opts)
      client.baz(1, 2, 3).should == 5
    end
  end

  describe "handling compilation log" do
    it "should inject compile log into response" do
      response = {
        "value" => {
          "result" => {
            "compile_log_id" => "cafe"
          }
        }
      }

      @nats_rpc.should_receive(:send_request).
        with("foo.bar", test_rpc_args).and_yield(response)

      rm = double(Bosh::Director::Api::ResourceManager)
      rm.should_receive(:get_resource).with("cafe").and_return("blob")
      rm.should_receive(:delete_resource).with("cafe")
      Bosh::Director::Api::ResourceManager.should_receive(:new).and_return(rm)

      client = make("foo", "bar")
      value = client.baz(*test_args)
      value["result"]["compile_log"].should == "blob"
    end
  end

  describe "formatting RPC remote exceptions" do
    it "supports old style (String)" do
      client = make("foo", "bar")
      client.format_exception("message string").should == "message string"
    end

    it "supports new style (Hash)" do
      exception = {
        "message" => "something happened",
        "backtrace" => ["in zbb.rb:35", "in zbb.rb:26"],
        "blobstore_id" => "deadbeef"
      }

      rm = mock(BD::Api::ResourceManager)
      BD::Api::ResourceManager.stub(:new).and_return(rm)
      rm.should_receive(:get_resource).with("deadbeef").
        and_return("Failed to compile: no such file 'zbb'")
      rm.should_receive(:delete_resource).with("deadbeef")

      expected_error =
        "something happened\nin zbb.rb:35\nin zbb.rb:26\n" +
        "Failed to compile: no such file 'zbb'"

      client = make("foo", "bar")
      client.format_exception(exception).should == expected_error
    end
  end
end
