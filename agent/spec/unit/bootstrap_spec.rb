# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Agent::Bootstrap do

  before(:each) do
    Bosh::Agent::Config.infrastructure_name = "dummy"
    Bosh::Agent::Config.platform_name = "dummy"

    @processor = Bosh::Agent::Bootstrap.new

    Bosh::Agent::Util.stub(:block_device_size).and_return(7903232)
    Bosh::Agent::Config.infrastructure.stub(:load_settings).and_return(complete_settings)
    Bosh::Agent::Config.platform.stub(:get_data_disk_device_name).and_return("/dev/dummy")

    # We just want to avoid this to accidently be invoked on dev systems
    Bosh::Agent::Util.stub(:update_file)
    @processor.stub(:setup_data_disk)
    @processor.stub(:partition_disk)
    @processor.stub(:mem_total).and_return(3951616)
  end

  it "should not setup iptables without settings" do
    @processor.load_settings
    @processor.stub!(:iptables).and_raise(Bosh::Agent::Error)
    @processor.update_iptables
  end

  it "should create new iptables filter chain" do
    new = "-N agent-filter"
    append_chain = "-A OUTPUT -j agent-filter"
    default_rules = ["-P INPUT ACCEPT", "-P FORWARD ACCEPT", "-P OUTPUT ACCEPT"]
    list_rules = default_rules.join("\n")

    settings = complete_settings
    settings["iptables"] = {"drop_output" => ["n.n.n.n", "x.x.x.x"]}
    Bosh::Agent::Config.infrastructure.stub(:load_settings).and_return(settings)
    @processor.load_settings

    @processor.should_receive(:iptables).with(new).and_return("")
    @processor.should_receive(:iptables).with("-S").and_return(list_rules)
    @processor.should_receive(:iptables).with(append_chain).and_return("")

    settings["iptables"]["drop_output"].each do |dest|
      rule = "-A agent-filter -d #{dest} -m owner ! --uid-owner root -j DROP"
      @processor.should_receive(:iptables).with(rule).and_return("")
    end

    @processor.update_iptables
  end

  it "should update existing iptables filter chain" do
    new = "-N agent-filter"
    append_chain = "-A OUTPUT -j agent-filter "
    default_rules = ["-P INPUT ACCEPT", "-P FORWARD ACCEPT", "-P OUTPUT ACCEPT"]
    list_rules = default_rules.join("\n") + append_chain

    settings = complete_settings
    settings["iptables"] = {"drop_output" => ["n.n.n.n", "x.x.x.x"]}
    Bosh::Agent::Config.infrastructure.stub(:load_settings).and_return(settings)
    @processor.load_settings

    @processor.should_receive(:iptables).with(new).and_raise(Bosh::Agent::Error)
    @processor.should_receive(:iptables).with("-F agent-filter").and_return("")
    @processor.should_receive(:iptables).with("-S").and_return(list_rules)

    settings["iptables"]["drop_output"].each do |dest|
      rule = "-A agent-filter -d #{dest} -m owner ! --uid-owner root -j DROP"
      @processor.should_receive(:iptables).with(rule).and_return("")
    end

    @processor.update_iptables
  end

  # This doesn't quite belong here
  it "should configure mbus with nats server uri" do
    @processor.load_settings
    Bosh::Agent::Config.setup({"logging" => { "file" => StringIO.new, "level" => "DEBUG" }, "mbus" => nil, "blobstore_options" => {}})
    @processor.update_mbus
    Bosh::Agent::Config.mbus.should == "nats://user:pass@11.0.0.11:4222"
  end

  it "should configure blobstore with settings data" do
    @processor.load_settings

    settings = {
      "logging" => { "file" => StringIO.new, "level" => "DEBUG" }, "mbus" => nil, "blobstore_options" => { "user" => "agent" }
    }
    Bosh::Agent::Config.setup(settings)

    @processor.update_blobstore
    blobstore_options = Bosh::Agent::Config.blobstore_options
    blobstore_options["user"].should == "agent"
  end

  it "should swap on data disk" do
    @processor.data_sfdisk_input.should == ",3859,S\n,,L\n"
  end

  def complete_settings
    settings_json = %q[{"vm":{"name":"vm-273a202e-eedf-4475-a4a1-66c6d2628742","id":"vm-51290"},"disks":{"ephemeral":1,"persistent":{"250":2},"system":0},"mbus":"nats://user:pass@11.0.0.11:4222","networks":{"network_a":{"netmask":"255.255.248.0","mac":"00:50:56:89:17:70","ip":"172.30.40.115","default":["gateway","dns"],"gateway":"172.30.40.1","dns":["172.30.22.153","172.30.22.154"],"cloud_properties":{"name":"VLAN440"}}},"blobstore":{"plugin":"simple","properties":{"password":"Ag3Nt","user":"agent","endpoint":"http://172.30.40.11:25250"}},"ntp":["ntp01.las01.emcatmos.com","ntp02.las01.emcatmos.com"],"agent_id":"a26efbe5-4845-44a0-9323-b8e36191a2c8"}]
    Yajl::Parser.new.parse(settings_json)
  end

end

