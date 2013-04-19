# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'
require 'net/https'
require 'yajl'
require 'tempfile'

describe "http messages" do

  def http(method, args=nil)
    uri = URI.parse(@http_uri)
    req = Net::HTTP::Post.new(uri.request_uri)
    req.basic_auth(@user, @pass)

    hash = {:reply_to => 'rspec', :method => method}
    hash['arguments'] = args if args
    req.body = Yajl::Encoder.encode(hash)

    http_connection = Net::HTTP.new(uri.host, uri.port)
    http_connection.use_ssl = true
    http_connection.verify_mode = OpenSSL::SSL::VERIFY_NONE

    http_connection.start do |http|
      response = http.request(req)
      msg = Yajl::Parser.parse(response.body)
      if msg.has_key?('value')
        yield msg['value']
      else
        yield msg
      end
    end
  end

  def http_up?
    uri = URI.parse(@http_uri)
    req = Net::HTTP::Post.new(uri.request_uri)
    req.basic_auth(@user, @pass)

    http_connection = Net::HTTP.new(uri.host, uri.port)
    http_connection.use_ssl = true
    http_connection.verify_mode = OpenSSL::SSL::VERIFY_NONE

    http_connection.start do |http|
      response = http.request(req)
      return response.is_a?(Net::HTTPSuccess)
    end
  rescue Errno::ECONNREFUSED
    false
  end

  before(:all) do
    @user = "http"
    @pass = @user.reverse
    @port = get_free_port
    smtp_port = get_free_port
    @http_uri = "https://#{@user}:#{@pass}@localhost:#{@port}/agent"
    @agent_id = "rspec_agent"
    agent_out = Tempfile.new('agent_out')

    puts "starting http agent"
    agent = File.expand_path("../../../bin/bosh_agent", __FILE__)
    @basedir = File.expand_path("../../../tmp", __FILE__)
    FileUtils.mkdir_p(@basedir) unless Dir.exist?(@basedir)
    command = "ruby #{agent} -n #{@http_uri} -t #{smtp_port} -a #{@agent_id} -h 1 -b #{@basedir}"
    @agent_pid = Process.spawn(command, out: agent_out.path, err: agent_out.path)

    counter = 0
    while !http_up?
      counter += 1
      # wait max 10 seconds for the agent to start
      if counter > 100
        puts File.read(agent_out)
        raise "unable to connect to agent"
      end
      sleep 0.1
    end
  end

  after(:all) do
    if @agent_pid
      puts "stopping agent"
      Process.kill(:TERM, @agent_pid)
      Process.waitpid(@agent_pid)
    else
      raise "unable to stop agent, you need to clean up by hand"
    end
    FileUtils.rm_rf(@basedir)
  end

  it "should respond to state message" do
    http('state') do |msg|
      msg.should have_key('deployment')
      msg.should have_key('networks')
      msg.should have_key('resource_pool')
      msg.should have_key('agent_id')
      msg.should have_key('vm')
      msg.should have_key('job_state')
    end
  end

  it "should respond to state message with vitals" do
    http('state', ['full']) do |msg|
      msg.should have_key('deployment')
      msg.should have_key('networks')
      msg.should have_key('resource_pool')
      msg.should have_key('agent_id')
      msg.should have_key('vm')
      msg.should have_key('job_state')
      msg.should have_key('vitals')
    end
  end

  it "should respond to ping message" do
    http('ping') do |msg|
      msg.should == 'pong'
    end
  end

  it "should respond noop message" do
    http('noop') do |msg|
      msg.should == 'nope'
    end
  end

  it "should respond to start message" do
    http('start') do |msg|
      msg.should == 'started'
    end
  end

  it "should respond to drain message" do
    task = nil
    http('drain', ['shutdown']) do |msg|
      task = msg
      task['state'].should == "running"
      task['agent_task_id'].should_not be_nil
    end

    while task.is_a?(Hash) && task['state'] == "running"
      sleep 0.5
      http('get_task', [ task['agent_task_id'] ]) do |msg|
        task = msg
        unless task.is_a?(Hash) && task['state']
          task.should == 0
          break
        end
      end
    end
  end

  it "should respond to stop message" do
    task = nil
    http('stop', []) do |msg|
      task = msg
      task['state'].should == "running"
      task['agent_task_id'].should_not be_nil
    end

    while task.is_a?(Hash) && task['state'] == "running"
      sleep 0.5
      http('get_task', [ task['agent_task_id'] ]) do |msg|
        task = msg
        unless task.is_a?(Hash) && task['state']
          task.should == 'stopped'
          break
        end
      end
    end
  end

  it "should respond to apply message" do
    task = nil
    http('apply', [{'foo' => 'bar'}]) do |msg|
      task = msg
      task['state'].should == "running"
      task['agent_task_id'].should_not be_nil
    end

    while task['state'] == "running"
      sleep 0.1
      http('get_task', [ task['agent_task_id'] ]) do |msg|
        task = msg
        unless task['state']
          msg.should have_key('foo')
          break
        end
      end
    end
  end

end
