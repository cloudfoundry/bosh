require 'spec_helper'
require 'micro/watcher'
require 'micro/network'

describe VCAP::Micro::Watcher do
  def mock_network(state)
    network = stub("network")
    network.stub(:up?).and_return(state)
    network
  end

  def mock_identity(ip)
    identity = stub("identity")
    identity.stub(:ip).and_return(ip)
    identity
  end

  def stub_network(ip, gw)
    VCAP::Micro::Network.stub(:local_ip).and_return(ip)
    VCAP::Micro::Network.stub(:gateway).and_return(gw)
  end

  it "should watch network changes" do
    ip = "1.2.3.4"

    stub_network(ip, "1.2.3.5")
    VCAP::Micro::Network.should_receive(:ping).exactly(1).times.and_return(true)
    VCAP::Micro::Network.should_receive(:lookup).exactly(1).
      times.and_return(VCAP::Micro::Watcher::A_ROOT_SERVER_IP)

    w = VCAP::Micro::Watcher.new(mock_network(true), mock_identity(ip))
    w.check
  end

  it "should increase the sleep if there is no gateway" do
    VCAP::Micro::Network.stub(:gateway).and_return(nil)

    w = VCAP::Micro::Watcher.new(mock_network(true), mock_identity("1.2.3.4"))
    w.check
    w.sleep.should == VCAP::Micro::Watcher::DEFAULT_SLEEP * 2
  end

  it "should restart network if it can't lookup cloudfoundry.com" do
    ip = "1.2.3.4"

    stub_network(ip, "1.2.3.5")
    VCAP::Micro::Network.should_receive(:ping).exactly(1).
      times.and_return(true)
    VCAP::Micro::Network.should_receive(:lookup).and_return(nil)

    network = mock_network(true)
    network.should_receive(:online?).exactly(1).times

    w = VCAP::Micro::Watcher.new(network, mock_identity(ip))
    w.check
  end

  it "should update the IP if it has changed" do
    new_ip = "1.2.3.6"

    stub_network(new_ip, "1.2.3.5")
    VCAP::Micro::Network.stub(:lookup).
      and_return(VCAP::Micro::Watcher::A_ROOT_SERVER_IP)
    VCAP::Micro::Network.should_receive(:ping).exactly(1).times.
      and_return(true)

    identity = mock_identity("1.2.3.4")
    identity.should_receive(:update_ip).with(new_ip).exactly(1).times
    identity.should_receive(:subdomain).exactly(1).times.and_return("vcap.me")

    w = VCAP::Micro::Watcher.new(mock_network(true), identity)
    w.check
  end

  it "should refresh the IP regularly" do
    ip = "1.2.3.4"

    stub_network(ip, "1.2.3.5")
    VCAP::Micro::Network.stub(:lookup).
      and_return(VCAP::Micro::Watcher::A_ROOT_SERVER_IP)
    VCAP::Micro::Network.should_receive(:ping).exactly(1).times.
      and_return(true)

    identity = mock_identity(ip)
    identity.should_receive(:update_ip).with(ip, true).exactly(1).times
    now = Time.now.to_i
    Time.stub(:now).and_return(now - 14500, now)
    w = VCAP::Micro::Watcher.new(mock_network(true), identity)
    w.check
  end

  describe "ping" do
    it "should try three pings before it considers it failed" do
      ip = "127.0.0.1"
      w = VCAP::Micro::Watcher.new(mock_network(true), mock_identity(ip))
      VCAP::Micro::Network.should_receive(:ping).with(ip).exactly(3).times.
        and_return(false)
      Kernel.should_receive(:sleep).with(5).exactly(2).times

      w.forgiving_ping(ip).should be_false
    end

    it "should succeed if the first ping returns true" do
      ip = "127.0.0.1"
      w = VCAP::Micro::Watcher.new(mock_network(true), mock_identity(ip))
      VCAP::Micro::Network.should_receive(:ping).with(ip).exactly(1).times.
        and_return(true)

      w.forgiving_ping(ip).should be_true
    end

    it "should succeed if the second ping returns true" do
      ip = "127.0.0.1"
      w = VCAP::Micro::Watcher.new(mock_network(true), mock_identity(ip))
      VCAP::Micro::Network.should_receive(:ping).with(ip).exactly(2).times.
        and_return(false, true)
        Kernel.should_receive(:sleep).with(5).exactly(1).times

      w.forgiving_ping(ip).should be_true
    end

    it "should succeed if the third ping returns true" do
      ip = "127.0.0.1"
      w = VCAP::Micro::Watcher.new(mock_network(true), mock_identity(ip))
      VCAP::Micro::Network.should_receive(:ping).with(ip).exactly(3).times.
        and_return(false, false, true)
        Kernel.should_receive(:sleep).with(5).exactly(2).times

      w.forgiving_ping(ip).should be_true
    end

  end

  describe "pause" do
    it "should be false by default" do
      ip = "127.0.0.1"
      w = VCAP::Micro::Watcher.new(mock_network(true), mock_identity(ip))
      w.paused.should be_false
    end

    it "should reset the sleep value on resume" do
      ip = "127.0.0.1"
      w = VCAP::Micro::Watcher.new(mock_network(true), mock_identity(ip))
      w.pause
      w.resume
      w.sleep.should == VCAP::Micro::Watcher::DEFAULT_SLEEP
    end
  end

end
