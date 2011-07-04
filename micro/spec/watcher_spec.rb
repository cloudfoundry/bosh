require 'spec_helper'
require 'micro/watcher'
require 'micro/network'

describe VCAP::Micro::Watcher do
  def mock_configurator(state, ip)
    network = stub("network")
    network.stub(:up?).and_return(state)

    identity = stub("identity")
    identity.stub(:ip).and_return(ip)

    configurator = stub("configurator")
    configurator.stub(:network).and_return(network)
    configurator.stub(:identity).and_return(identity)

    configurator
  end

  it "should watch network changes" do
    ip = "1.2.3.4"
    c = mock_configurator(true, ip)

    VCAP::Micro::Network.stub(:local_ip).and_return(ip)
    VCAP::Micro::Network.stub(:gateway).and_return("1.2.3.5")
    VCAP::Micro::Network.should_receive(:ping).exactly(2).times.and_return(true)
    VCAP::Micro::Network.should_receive(:lookup).exactly(1).times.and_return("173.243.49.35")

    w = VCAP::Micro::Watcher.new(c)
    w.check
  end

  it "should increase the sleep if there is no gateway" do
    c = mock_configurator(true, "1.2.3.4")
    VCAP::Micro::Network.stub(:gateway).and_return(nil)

    w = VCAP::Micro::Watcher.new(c)
    w.check
    w.sleep.should == 10
  end

  it "should restart network if it can't ping the gateway" do
    ip = "1.2.3.4"
    c = mock_configurator(true, ip)
    VCAP::Micro::Network.stub(:local_ip).and_return(ip)
    VCAP::Micro::Network.stub(:gateway).and_return("1.2.3.5")

    VCAP::Micro::Network.should_receive(:ping).exactly(2).times.and_return(true, false)
    c.network.should_receive(:restart).exactly(1).times

    w = VCAP::Micro::Watcher.new(c)
    w.check
  end

  it "should restart network if it can't lookup cloudfoundry.com" do
    ip = "1.2.3.4"
    c = mock_configurator(true, ip)
    VCAP::Micro::Network.stub(:local_ip).and_return(ip)
    VCAP::Micro::Network.stub(:gateway).and_return("1.2.3.5")

    VCAP::Micro::Network.should_receive(:ping).exactly(2).times.and_return(true)
    VCAP::Micro::Network.should_receive(:lookup).and_return(nil)

    c.network.should_receive(:restart).exactly(1).times

    w = VCAP::Micro::Watcher.new(c)
    w.check
  end

  it "should update the IP if it has changed" do
    c = mock_configurator(true, "1.2.3.4")
    new_ip = "1.2.3.6"
    VCAP::Micro::Network.stub(:local_ip).and_return(new_ip)
    VCAP::Micro::Network.stub(:gateway).and_return("1.2.3.5")
    VCAP::Micro::Network.should_receive(:ping).exactly(2).times.and_return(true)

    c.identity.should_receive(:update_ip).with(new_ip).exactly(1).times

    w = VCAP::Micro::Watcher.new(c)
    w.check
  end
end
