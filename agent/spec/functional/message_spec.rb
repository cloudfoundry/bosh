require File.dirname(__FILE__) + '/../spec_helper'

require 'posix/spawn'
require 'nats/client'
require 'yajl'

describe "messages" do

  def nats(method, args=nil)
    catch :done do
      NATS.start(:uri => @nats_uri) do
        sid = NATS.subscribe('rspec') do |json|
          msg = Yajl::Parser.new.parse(json)
          msg.should have_key('value')
          if block_given?
            yield msg['value']
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

  def get_free_port
    socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
    socket.bind(Addrinfo.tcp("127.0.0.1", 0))
    port = socket.local_address.ip_port
    socket.close
    # race condition, but good enough for now
    port
  end

  # wait for the first heartbeat to appear or timeout after 5 seconds
  def wait_for_nats(timeout=5)
    printf("waiting for nats: ")
    count = 0
    begin
      catch :done do
        NATS.start(:uri => @nats_uri) do
          sid = NATS.subscribe('hm.agent.heartbeat.>') do |json|
            throw :done
          end
          NATS.timeout(sid, timeout) { raise "timeout waiting for nats to start" }
        end
      end
    rescue NATS::ConnectError => e
      sleep 0.1
      count += 1
      printf(".")
      if count > timeout * 10
        raise e
      else
        retry
      end
    end
    puts " done!"
  end

  before(:all) do
    @user = "nats"
    @pass = "nats"
    @port = get_free_port
    @nats_uri = "nats://#{@user}:#{@pass}@localhost:#{@port}"
    @agent_id = "rspec_agent"

    puts "starting nats"
    command = "nats-server --port #{@port} --user #{@user} --pass #{@pass}"
    @nats_pid = POSIX::Spawn::spawn(command)

    puts "starting agent"
    agent = File.expand_path("../../../bin/agent", __FILE__)
    @basedir = File.expand_path("../../../tmp", __FILE__)
    FileUtils.mkdir_p(@basedir) unless Dir.exist?(@basedir)
    command = "ruby #{agent} -n #{@nats_uri} -a #{@agent_id} -h 1 -b #{@basedir} -l ERROR"
    @agent_pid = POSIX::Spawn::spawn(command)
    wait_for_nats
  end

  it "should respond to state message" do
    nats('state') do |msg|
      msg.should have_key('deployment')
      msg.should have_key('networks')
      msg.should have_key('resource_pool')
      msg.should have_key('agent_id')
      msg.should have_key('vm')
      msg.should have_key('job_state')
    end
  end

  it "should respond to ping message" do
    nats('ping') do |msg|
      msg.should == 'pong'
    end
  end

  it "should respond to fetch logs message" do
    nats('noop') do |msg|
      msg.should == 'nope'
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
      msg.should == 'started'
    end
  end

  it "should respond to drain message" do
    nats('drain', ['shutdown', 'bar']) do |msg|
      msg.should == 0
    end
  end

  it "should respond to stop message" do
    nats('stop') do |msg|
      msg.should == 'stopped'
    end
  end

  after(:all) do
    puts "stopping agent"
    Process.kill(:TERM, @agent_pid)
    puts "stopping nats"
    Process.kill(:TERM, @nats_pid)
    FileUtils.rm_rf(@basedir)
  end
end
