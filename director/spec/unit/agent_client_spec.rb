require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::AgentClient do

  def convert_message_given_expects(given, expects)
    agent = Bosh::Director::AgentClient
    result = agent.convert_old_message_to_new(given)
    result.should == expects
  end

  it "should leave a correctly formatted no-value response alone" do
    message = { "state" => "running", "value" => nil, "agent_task_id" => 1 }
    convert_message_given_expects(message, message)
  end

  it "should leave a correctly formatted response alone" do
    message = { "state" => "running", "value" => {"key1" => 1, "key2" => 2},
                "agent_task_id" => 1 }
    convert_message_given_expects(message, message)
  end

  it "should fix a message that is not wrapped in value" do
    actual = { "key1" => 1, "key2" => 2 }
    expected = { "state" => "done", "value" => actual, "agent_task_id" => nil }
    convert_message_given_expects(actual, expected)
  end

  it "should fix a message that is an array" do
    actual = [1, 2, 3]
    expected = { "state" => "done", "value" => actual, "agent_task_id" => nil }
    convert_message_given_expects(actual, expected)
  end

  it "should fix a message that is in the old value format" do
    actual = { "key1" => 1, "key2" => 2 }
    expected = { "state" => "done", "value" => {"key1" => 1, "key2" => 2},
                 "agent_task_id" => nil }
    convert_message_given_expects(actual, expected)
  end

  it "should fix a nil message" do
    actual = nil
    expected = { "state" => "done", "value" => nil, "agent_task_id" => nil }
    convert_message_given_expects(actual, expected)
  end

  it "should wrap a message that has no value" do
    actual = { "state" => "done", "agent_task_id" => 1 }
    convert_message_given_expects(actual, actual)
  end

  it "should fix a message that has no state or agent_task_id" do
    # If there was no state, then we are assuming this was the old message
    # format.
    actual = { "value" => "blah" }
    expected = { "state" => "done", "value" => "blah", "agent_task_id" => nil }
    convert_message_given_expects(actual, expected)
  end

  it "should fix a message that has only a string" do
    actual = "something"
    expected = { "state" => "done", "value" => actual, "agent_task_id" => nil }
    convert_message_given_expects(actual, expected)
  end

  it "should fix a message that has only a float" do
    actual = 1.01
    expected = { "state" => "done", "value" => actual, "agent_task_id" => nil }
    convert_message_given_expects(actual, expected)
  end

  it "should use vm credentials" do
    cloud = mock("cloud")
    nats_rpc = mock("nats_rpc")

    Bosh::Director::Config.stub!(:cloud).and_return(cloud)
    Bosh::Director::Config.stub!(:nats_rpc).and_return(nats_rpc)
    Bosh::Director::Config.encryption = true

    deployment = Bosh::Director::Models::Deployment.make
    stemcell = Bosh::Director::Models::Stemcell.make(:cid => "stemcell-id")
    cloud_properties = {"ram" => "2gb"}
    env = {}
    network_settings = {"network_a" => {"ip" => "1.2.3.4"}}


    cloud.should_receive(:create_vm).with(kind_of(String), "stemcell-id",
                                           {"ram" => "2gb"}, network_settings, [99],
                                           {"bosh" =>
                                             { "credentials" =>
                                               { "crypt_key" => kind_of(String),
                                                 "sign_key" => kind_of(String)}}})

    vm = Bosh::Director::VmCreator.new.create(deployment, stemcell,
                                              cloud_properties,
                                              network_settings, Array(99),
                                              env)
    handler = Bosh::EncryptionHandler.new(vm.agent_id, vm.credentials)

    nats_rpc.should_receive(:send_request) do |*args, &blk|
      data = args[1]["encrypted_data"]
      # decrypt to initiate session
      handler.decrypt(data)
      blk.call("encrypted_data" => handler.encrypt("value" => "pong"))
    end

    client = Bosh::Director::AgentClient.new(vm.agent_id)
    client.ping.should == "pong"
  end

end
