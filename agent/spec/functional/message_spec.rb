# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + "/../spec_helper"

require "posix/spawn"
require "nats/client"
require "yajl"

describe "messages" do

  def nats(method, args=nil)
    catch :done do
      NATS.start(:uri => @nats_uri) do
        sid = NATS.subscribe('rspec') do |json|
          msg = Yajl::Parser.new.parse(json)
          if block_given?
            yield msg
          end
          throw :done
        end
        NATS.timeout(sid, 2) { raise "timeout error" }

        hash = {:reply_to => 'rspec', :method => method}
        hash['arguments'] = args if args
        msg = Yajl::Encoder.encode(hash)
        NATS.publish("agent.#{@agent_id}", msg)
      end
    end
  end

  def get_value(msg)
    msg.should have_key('value')
    msg['value']
  end

  # wait for the first heartbeat to appear or timeout after 5 seconds
  def wait_for_nats(timeout=5)
    count = 0
    begin
      catch :done do
        NATS.start(:uri => @nats_uri) do
          sid = NATS.subscribe('hm.agent.heartbeat.>') do |json|
            throw :done
          end
          NATS.timeout(sid, timeout) do
            raise "timeout waiting for nats to start"
          end
        end
      end
    rescue NATS::ConnectError => e
      sleep 0.1
      count += 1
      if count > timeout * 10
        raise e
      else
        retry
      end
    end
  end

  before(:all) do
    @user = "nats"
    @pass = "nats"
    @port = get_free_port
    @nats_uri = "nats://#{@user}:#{@pass}@localhost:#{@port}"
    @agent_id = "rspec_agent"

    command = "nats-server --port #{@port} --user #{@user} --pass #{@pass}"
    @nats_pid = POSIX::Spawn::spawn(command)

    agent = File.expand_path("../../../bin/agent", __FILE__)
    @basedir = File.expand_path("../../../tmp", __FILE__)
    FileUtils.mkdir_p(@basedir) unless Dir.exist?(@basedir)
    command = "ruby #{agent} -n #{@nats_uri} -a #{@agent_id} -h 1"
    command += " -b #{@basedir} -l ERROR"
    @agent_pid = POSIX::Spawn::spawn(command)
    wait_for_nats
  end

  it "should respond to state message" do
    nats('state') do |msg|
      value = get_value(msg)
      value.should have_key('deployment')
      value.should have_key('networks')
      value.should have_key('resource_pool')
      value.should have_key('agent_id')
      value.should have_key('vm')
      value.should have_key('job_state')
    end
  end

  it "should respond to ping message" do
    nats('ping') do |msg|
      value = get_value(msg)
      value.should == 'pong'
    end
  end

  it "should respond to noop message" do
    nats('noop') do |msg|
      value = get_value(msg)
      value.should == 'nope'
    end
  end

  it "should respond to list disk message" do
    pending "need to fake disks"
    nats('list_disk', [])
  end

  it "should respond to fetch logs message" do
    pending "need blobstore"
    nats('fetch_logs', ['agent', ['--all']])
  end

  it "should respond to start message" do
    nats('start') do |msg|
      value = get_value(msg)
      value.should == 'started'
    end
  end

  it "should respond to drain message" do
    task = nil
    nats("drain", ["shutdown", "bar"]) do |msg|
      task = msg
      task["state"].should == "running"
      task["agent_task_id"].should_not be_nil
    end

    while task.is_a?(Hash) && task["state"] == "running"
      sleep 0.5
      nats("get_task", [ task["agent_task_id"] ]) do |msg|
        task = msg
        unless task.is_a?(Hash) && task["state"]
          task.should == 0
          break
        end
      end
    end
  end

  it "should respond to stop message" do
    task = nil
    nats("stop") do |msg|
      task = msg
      task["state"].should == "running"
      task["agent_task_id"].should_not be_nil
    end

    while task.is_a?(Hash) && task["state"] == "running"
      sleep 0.5
      nats("get_task", [ task["agent_task_id"] ]) do |msg|
        task = msg
        unless task.is_a?(Hash) && task["state"]
          task.should == "stopped"
          break
        end
      end
    end
  end

  it "should respond to compile message" do
    pending "need to mock package to compile"
    nats('compile_package') do |msg|
      msg.should have_key('value')
      value = msg['value']
      value.should have_key('state')
    end
  end

  it "should return an exception for unknow message" do
    nats('foobar') do |msg|
      msg.should have_key('exception')
    end
  end

  after(:all) do
    Process.kill(:TERM, @agent_pid)
    Process.kill(:TERM, @nats_pid)
    FileUtils.rm_rf(@basedir)
  end
end
