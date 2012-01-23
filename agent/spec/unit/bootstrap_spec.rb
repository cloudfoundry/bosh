require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Agent::Bootstrap do

  before(:each) do
    Bosh::Agent::Config.infrastructure_name = "dummy"

    @processor = Bosh::Agent::Bootstrap.new

    Bosh::Agent::Util.stub(:block_device_size).and_return(7903232)
    Bosh::Agent::Config.infrastructure.stub(:load_settings).and_return(complete_settings)

    # We just want to avoid this to accidently be invoked on dev systems
    @processor.stub(:update_file)
    @processor.stub(:restart_networking_service)
    @processor.stub(:setup_data_disk)
    @processor.stub(:partition_disk)
    @processor.stub(:mem_total).and_return(3951616)
    @processor.stub(:gratuitous_arp)
  end

  it 'should setup networking' do
    @processor.load_settings
    @processor.stub!(:detect_mac_addresses).and_return({"00:50:56:89:17:70" => "eth0"})
    @processor.setup_networking
  end

  # FIXME: pending network config refactoring
  #it "should fail when network information is incomplete" do
  #  @processor.load_settings
  #  @processor.stub!(:detect_mac_addresses).and_return({"00:50:56:89:17:70" => "eth0"})
  #  lambda { @processor.setup_networking }.should raise_error(Bosh::Agent::MessageHandlerError, /contains invalid characters/)
  #end

  it "should generate ubuntu network files" do
    @processor.load_settings
    @processor.stub!(:detect_mac_addresses).and_return({"00:50:56:89:17:70" => "eth0"})
    @processor.stub!(:update_file) do |data, file|
      # FIMXE: clean this mess up
      case file
      when '/etc/network/interfaces'
        data.should == "auto lo\niface lo inet loopback\n\nauto eth0\niface eth0 inet static\n    address 172.30.40.115\n    network 172.30.40.0\n    netmask 255.255.248.0\n    broadcast 172.30.47.255\n    gateway 172.30.40.1\n\n"
      when '/etc/resolv.conf'
        data.should == "nameserver 172.30.22.153\nnameserver 172.30.22.154\n"
      end
    end

    @processor.setup_networking
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

