# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Agent::Handler do

  before(:each) do
    @nats = mock('nats')
    EM.stub(:run).and_yield
    NATS.stub(:connect).and_return(@nats)

    # TODO: refactor the whole thing to avoid stubs such as these
    Bosh::Agent::AlertProcessor.stub(:start)
    Bosh::Agent::Heartbeat.stub(:enable)

    Bosh::Agent::Config.process_alerts = true
    Bosh::Agent::Config.smtp_port      = 55213
    Bosh::Agent::Config.smtp_user      = "user"
    Bosh::Agent::Config.smtp_password  = "pass"

    EM.stub!(:next_tick).and_return do |block|
      block.call
    end
  end

  it "should result in a value payload" do
    handler = Bosh::Agent::Handler.new
    payload = handler.process(Bosh::Agent::Message::Ping, nil)
    payload.should == {:value => "pong"}
  end

  it "should attempt to start alert processor when handler starts" do
    Bosh::Agent::AlertProcessor.should_receive(:start).with("127.0.0.1", 55213, "user", "pass")

    handler = Bosh::Agent::Handler.new
    handler.start
  end

  it "should not start alert processor if alerts are disabled via config" do
    Bosh::Agent::Config.process_alerts = false
    Bosh::Agent::AlertProcessor.should_not_receive(:start)

    handler = Bosh::Agent::Handler.new
    handler.start
  end

  it "should result in an exception payload" do
    handler = Bosh::Agent::Handler.new

    klazz = Class.new do
      def self.process(args)
        raise Bosh::Agent::MessageHandlerError, "boo!"
      end
    end
    payload = handler.process(klazz, nil)
    payload.should have_key :exception
    exception = payload[:exception]
    exception.should have_key :message
    exception[:message].should == "boo!"
  end

  it "should process long running tasks" do
    handler = Bosh::Agent::Handler.new
    handler.start

    klazz = Class.new do
      def self.process(args)
        "result"
      end
      def self.long_running?; true; end
    end

    agent_task_id = nil
    @nats.should_receive(:publish) do |reply_to, payload|
      reply_to.should == "bogus_reply_to"
      msg = Yajl::Parser.new.parse(payload)
      agent_task_id = msg["value"]["agent_task_id"]
    end
    handler.process_long_running("bogus_reply_to", klazz, nil)

    @nats.should_receive(:publish) do |reply_to, payload|
      msg = Yajl::Parser.new.parse(payload)
      msg.should == {"value" => "result"}
    end
    handler.handle_get_task("another_bogus_id", agent_task_id)
  end

  it "should have running state for long running task"

  it "should support CamelCase message handler class names" do
    ::Bosh::Agent::Message::CamelCasedMessageHandler = Class.new do
      def self.process(args); end
    end
    handler = Bosh::Agent::Handler.new
    handler.processors.keys.should include("camel_cased_message_handler")
  end

  it "handle message should fail on broken json" do
    logger = Bosh::Agent::Config.logger

    logger.should_receive(:info).with(/Message processors/)
    logger.should_receive(:info).with(/Yajl::ParseError/)

    handler = Bosh::Agent::Handler.new
    handler.handle_message('}}}b0rked}}}json')
  end

  it "should retry nats connection when it fails" do
    retries = Bosh::Agent::Handler::MAX_NATS_RETRIES
    NATS.stub(:connect).and_raise(NATS::ConnectError)
    handler = Bosh::Agent::Handler.new
    handler.stub!(:sleep)
    handler.should_receive(:sleep).exactly(retries).times
    handler.start
  end

  it "should report unexpected errors then terminate its thread in 15 seconds" do
    handler = Bosh::Agent::Handler.new

    klazz = Class.new do
      def self.process(args)
        raise "How unexpected of you!"
      end
    end
    handler.should_receive(:kill_main_thread_in).once
    handler.instance_eval do
      @logger.should_receive(:error).with(
          /#<RuntimeError: How unexpected of you!/)
    end
    payload = handler.process(klazz, nil)
    payload[:exception].should match(/#<RuntimeError: How unexpected of you!/)
  end

  describe "Encryption" do

    before(:each) do
      @credentials = Bosh::EncryptionHandler.generate_credentials
      Bosh::Agent::Config.credentials = @credentials

      @handler = Bosh::Agent::Handler.new
      @handler.nats = @nats

      @encryption_handler = Bosh::EncryptionHandler.new("client_id", @credentials)

      @cipher = Gibberish::AES.new(@credentials["crypt_key"])
    end

    it "should decrypt message and encrypt response with credentials" do

      # The expectation uses a non-existent message handler to avoid the handler
      # to spawn a thread.
      @nats.should_receive(:publish).with("inbox.client_id",
                                          kind_of(String), nil
      ) { |*args|
        msg = @encryption_handler.decode(args[1])
        msg["session_id"].should == @encryption_handler.session_id

        decrypted_data = @encryption_handler.decrypt(msg["encrypted_data"])
        decrypted_data["exception"].should have_key("message")
        decrypted_data["exception"]["message"].should match(/bogus_ping/)
      }

      encrypted_data = @encryption_handler.encrypt(
        "method" => "bogus_ping", "arguments" => []
      )

      result = @handler.handle_message(
        @encryption_handler.encode(
          "reply_to" => "inbox.client_id",
          "session_id" => @encryption_handler.session_id,
          "encrypted_data" => encrypted_data
        )
      )
    end

    it "should handle decrypt failure" do
      @encryption_handler.encrypt("random" => "stuff")

      @handler.stub!(:log_encryption_error)
      @handler.should_receive(:log_encryption_error) { |*args|
        lambda {
          raise args[0]
        }.should raise_error(Bosh::EncryptionHandler::DecryptionError)
      }

      @handler.handle_message(
        @encryption_handler.encode(
          "reply_to" => "inbox.client_id",
          "session_id" => @encryption_handler.session_id,
          "encrypted_data" => "junk"
        )
      )
    end

    it "should handle session errors" do
      encrypted_data = @encryption_handler.encrypt(
        "method" => "bogus_message", "arguments" => []
      )

      @nats.should_receive(:publish).with("inbox.client_id",
                                          kind_of(String), nil)

      @handler.handle_message(
        @encryption_handler.encode(
          "reply_to" => "inbox.client_id",
          "session_id" => @encryption_handler.session_id,
          "encrypted_data" => encrypted_data
        )
      )

      encrypted_data2 = @encryption_handler.encrypt(
        "method" => "bogus_message", "arguments" => []
      )

      message = @encryption_handler.decode(
          @cipher.decrypt(encrypted_data)
      )

      data = @encryption_handler.decode(message["json_data"])
      data["session_id"] = "bosgus_session_id"

      json_data = @encryption_handler.encode(data)
      message["hmac"] = @encryption_handler.signature(json_data)
      message["json_data"] = json_data

      encrypted_bad_data = @cipher.encrypt(@encryption_handler.encode(message))

      @handler.stub!(:log_encryption_error)
      @handler.should_receive(:log_encryption_error) { |*args|
        lambda {
          raise args[0]
        }.should raise_error(Bosh::EncryptionHandler::SessionError, /session_id mismatch/)
      }

      @handler.handle_message(
        @encryption_handler.encode(
          "reply_to" => "inbox.client_id",
          "session_id" => @encryption_handler.session_id,
          "encrypted_data" => encrypted_bad_data
        )
      )
    end

    it "should handle signature errors" do
      encrypted_data = @encryption_handler.encrypt(
        "method" => "bogus_message", "arguments" => []
      )
      message = @encryption_handler.decode(
          @cipher.decrypt(encrypted_data)
      )
      message["hmac"] = @encryption_handler.signature("some other data")

      encrypted_bad_data = @cipher.encrypt(@encryption_handler.encode(message))

      @handler.stub!(:log_encryption_error)
      @handler.should_receive(:log_encryption_error) { |*args|
        lambda {
          raise args[0]
        }.should raise_error(Bosh::EncryptionHandler::SignatureError, /Expected hmac/)
      }

      @handler.handle_message(
        @encryption_handler.encode(
          "reply_to" => "inbox.client_id",
          "session_id" => @encryption_handler.session_id,
          "encrypted_data" => encrypted_bad_data
        )
      )
    end

    it "should handle sequence number errors" do
      encrypted_data = @encryption_handler.encrypt(
        "method" => "bogus_message", "arguments" => []
      )

      @nats.should_receive(:publish).with("inbox.client_id",
                                          kind_of(String), nil)
      @handler.handle_message(
        @encryption_handler.encode(
          "reply_to" => "inbox.client_id",
          "session_id" => @encryption_handler.session_id,
          "encrypted_data" => encrypted_data
        )
      )

      @handler.stub!(:log_encryption_error)
      @handler.should_receive(:log_encryption_error) { |*args|
        lambda {
          raise args[0]
        }.should raise_error(Bosh::EncryptionHandler::SequenceNumberError)
      }

      # Send it again
      @handler.handle_message(
        @encryption_handler.encode(
          "reply_to" => "inbox.client_id",
          "session_id" => @encryption_handler.session_id,
          "encrypted_data" => encrypted_data
        )
      )
    end
  end

  it "should raise a RemoteException when message > NATS_MAX_PAYLOAD" do
    payload = "a" * (Bosh::Agent::Handler::NATS_MAX_PAYLOAD_SIZE + 1)
    @nats.should_receive(:publish).with("reply", "exception", nil)

    mock = double(Bosh::Agent::RemoteException)
    mock.stub(:to_hash).and_return("exception")
    Bosh::Agent::RemoteException.should_receive(:new).and_return(mock)

    handler = Bosh::Agent::Handler.new
    handler.start
    handler.publish("reply", payload)
  end
end
