require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Agent::Handler do 

  before(:each) do
    @nats = mock('nats')
    NATS.stub(:start).and_yield
    NATS.stub(:connect).and_return(@nats)

    logger = mock('logger')
    logger.stub!(:info)
    Bosh::Agent::Config.logger = logger
  end

  it "should result in a value payload" do
    handler = Bosh::Agent::Handler.new
    payload = handler.process(Bosh::Agent::Message::Ping, nil)
    payload.should == {:value => "pong"}
  end

  it "should result in an exception payload" do
    handler = Bosh::Agent::Handler.new

    klazz = Class.new do
      def self.process(args)
        raise Bosh::Agent::MessageHandlerError, "boo!"
      end
    end
    payload = handler.process(klazz, nil)
    payload.should == {:exception => "#<Bosh::Agent::MessageHandlerError: boo!>"}
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

end
