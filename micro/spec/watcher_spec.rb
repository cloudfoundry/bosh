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

  it "should watch network changes" do
    ip = "1.2.3.4"

    VCAP::Micro::Network.stub(:local_ip).and_return(ip)
    VCAP::Micro::Network.stub(:gateway).and_return("1.2.3.5")
    VCAP::Micro::Network.should_receive(:ping).exactly(1).times.and_return(true)
    VCAP::Micro::Network.should_receive(:lookup).exactly(1).times.and_return("173.243.49.35")

    w = VCAP::Micro::Watcher.new(mock_network(true), mock_identity(ip))
    w.check
  end

  it "should increase the sleep if there is no gateway" do
    VCAP::Micro::Network.stub(:gateway).and_return(nil)

    w = VCAP::Micro::Watcher.new(mock_network(true), mock_identity("1.2.3.4"))
    w.check
    w.sleep.should == 30
  end

  it "should restart network if it can't ping the gateway" do
    ip = "1.2.3.4"

    VCAP::Micro::Network.stub(:local_ip).and_return(ip)
    VCAP::Micro::Network.stub(:gateway).and_return("1.2.3.5")

    VCAP::Micro::Network.should_receive(:ping).exactly(1).times.and_return(false)
    network = mock_network(true)
    network.should_receive(:connection_lost).exactly(1).times

    w = VCAP::Micro::Watcher.new(network, mock_identity(ip))
    w.check
  end

  it "should restart network if it can't lookup cloudfoundry.com" do
    ip = "1.2.3.4"

    VCAP::Micro::Network.stub(:local_ip).and_return(ip)
    VCAP::Micro::Network.stub(:gateway).and_return("1.2.3.5")

    VCAP::Micro::Network.should_receive(:ping).exactly(1).times.and_return(true)
    VCAP::Micro::Network.should_receive(:lookup).and_return(nil)

    network = mock_network(true)
    network.should_receive(:connection_lost).exactly(1).times

    w = VCAP::Micro::Watcher.new(network, mock_identity(ip))
    w.check
  end

  it "should update the IP if it has changed" do
    new_ip = "1.2.3.6"

    VCAP::Micro::Network.stub(:local_ip).and_return(new_ip)
    VCAP::Micro::Network.stub(:gateway).and_return("1.2.3.5")
    VCAP::Micro::Network.stub(:lookup).and_return(VCAP::Micro::Watcher::CLOUDFOUNDRY_IP)
    VCAP::Micro::Network.should_receive(:ping).exactly(1).times.and_return(true)

    identity = mock_identity("1.2.3.4")
    identity.should_receive(:update_ip).with(new_ip).exactly(1).times
    identity.should_receive(:subdomain).exactly(2).times.and_return("vcap.me")

    w = VCAP::Micro::Watcher.new(mock_network(true), identity)
    w.check
  end

  it "should refresh the IP regularly" do
    ip = "1.2.3.4"

    VCAP::Micro::Network.stub(:local_ip).and_return(ip)
    VCAP::Micro::Network.stub(:gateway).and_return("1.2.3.5")
    VCAP::Micro::Network.stub(:lookup).and_return(VCAP::Micro::Watcher::CLOUDFOUNDRY_IP)
    VCAP::Micro::Network.should_receive(:ping).exactly(1).times.and_return(true)

    identity = mock_identity(ip)
    identity.should_receive(:update_ip).with(ip).exactly(1).times
    now = Time.now.to_i
    Time.stub(:now).and_return(now - 14500, now)
    w = VCAP::Micro::Watcher.new(mock_network(true), identity)
    w.check
  end
end
