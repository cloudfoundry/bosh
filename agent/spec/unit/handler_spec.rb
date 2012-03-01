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
    payload[:exception].should match(/#<Bosh::Agent::MessageHandlerError: boo!/)
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
    Kernel.stub!(:sleep)
    Kernel.should_receive(:sleep).exactly(retries).times
    NATS.stub(:connect).and_raise(NATS::ConnectError)
    handler = Bosh::Agent::Handler.new
    handler.start
  end
end
