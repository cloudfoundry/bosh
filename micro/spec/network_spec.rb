require 'spec_helper'
require 'micro/network'

describe VCAP::Micro::Network do

  describe "type" do
    it "should accept dhcp type" do
      network = VCAP::Micro::Network.new
      network.type = :dhcp
      network.type.should == :dhcp
    end

    it "should accept static type" do
      network = VCAP::Micro::Network.new
      network.type = :static
      network.type.should == :static
    end
  end

  it "should be able to get the IP of localhost" do
    VCAP::Micro::Network.local_ip("localhost").should == "127.0.0.1"
  end

  it "should be able to ping localhost" do
    VCAP::Micro::Network.ping("localhost", 1).should be_true
  end

  it "should be able to get the IP of the default gateway" do
    VCAP::Micro::Network.gateway.should_not be_nil
  end

  describe "DNS lookup" do
    it "should work for www.ripe.net" do
      VCAP::Micro::Network.lookup("www.ripe.net").should ==
        "193.0.6.139"
    end

    it "should not work for an invalid name" do
      VCAP::Micro::Network.lookup("foo.bar").should be_nil
    end
  end

  describe "reverse DNS lookup" do
    it "should work for www.ripe.net" do
      VCAP::Micro::Network.reverse_lookup("193.0.6.139").should ==
        "www.ripe.net"
    end

    it "should not work for an invalid IP address" do
      VCAP::Micro::Network.reverse_lookup("260.0.6.139").should be_nil
    end
  end

  it "should create network config for dhcp" do
    tmp = "tmp/interfaces"
    with_constants "VCAP::Micro::Network::INTERFACES" => tmp do
      network = VCAP::Micro::Network.new
      network.should_receive(:restart).exactly(1).times
      network.dhcp
      File.exist?(tmp).should be_true
    end
  end

  it "should create network config for static" do
    tmp = "tmp/interfaces"
    with_constants "VCAP::Micro::Network::RESOLV_CONF" => tmp do
      state = double('statemachine')
      state.stub(:start)
      state.stub(:started)
      state.stub(:timeout)
      state.stub(:restart)
      state.stub(:state).and_return(:starting)
      Statemachine.stub(:build).and_return(state)
      network = VCAP::Micro::Network.new
      network.should_receive(:write_network_interfaces)
      network.should_receive(:restart).exactly(1).times
      conf = {
        "address" => "1.2.3.4",
        "netmask" => "255.255.255.0",
        "network" => "1.2.3.0",
        "broadcast" => "1.2.3.255",
        "dns" => "8.8.8.8"
      }
      network.static(conf)
      File.exist?(tmp).should be_true
    end
  end

end
