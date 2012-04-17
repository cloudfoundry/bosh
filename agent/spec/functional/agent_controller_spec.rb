# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

require "agent/http_handler"
require "rack/test"

module Bosh::Agent::Message
  class Sleep
    def self.process(args)
      sleep args.first.to_i
      { :message => "awake" }
    end

    def self.long_running?; true; end
  end
end

describe Bosh::Agent::AgentController do
  include Rack::Test::Methods

  def app
    handler = Bosh::Agent::HTTPHandler.new
    Bosh::Agent::AgentController.new(handler)
  end

  def agent_call(method, args=[])
    post "/agent", {}, {
      "CONTENT_TYPE" => "application/json",
      :input => Yajl::Encoder.encode({"reply_to" => "http_client", "method" => method, "arguments" => args })
    }
  end

  def agent_response
    Yajl::Parser.parse(last_response.body)
  end

  it "can ping" do
    agent_call("ping")
    last_response.status.should == 200
    agent_response.should == { "value" => "pong" }
  end

  it "should handle long_running" do
    agent_call("sleep", [2])
    last_response.status.should == 200

    task = agent_response["value"]
    task["state"].should == "running"

    while task["state"] == "running"
      sleep 0.5
      agent_call("get_task", [ task["agent_task_id"] ])
      last_response.status.should == 200
      task = agent_response["value"]
    end

    task["message"].should == "awake"
  end

  it "should throw unknown message" do
    agent_call("nosuch")
    last_response.status.should == 200
    agent_response.should have_key("exception")
  end

  it "should return generated apply_spec" do
    yml = File.expand_path("../../assets/apply_spec.yml", __FILE__)
    message = Bosh::Agent::Message::ReleaseApplySpec
    message.any_instance.stub(:release_apply_spec).and_return(yml)

    agent_call("release_apply_spec")

    last_response.status.should == 200
    response = agent_response
    response.should_not have_key("exception")
    response.should have_key("value")
    response["value"]["deployment"].should == "micro"
  end

  it "should throw exception with invalid apply_spec" do
    message = Bosh::Agent::Message::ReleaseApplySpec
    message.any_instance.stub(:release_apply_spec).and_return("")

    agent_call("release_apply_spec")

    last_response.status.should == 200
    agent_response.should have_key("exception")
  end
end
