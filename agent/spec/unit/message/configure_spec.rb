require File.dirname(__FILE__) + '/../../spec_helper'

describe Bosh::Agent::Message::Configure do

  before(:each) do

    tmp_base_dir = File.dirname(__FILE__) + "/../../tmp/#{Time.now.to_i}"
    if File.directory?(tmp_base_dir)
      FileUtils.rm_rf(tmp_base_dir)
    end
    Bosh::Agent::Config.base_dir = tmp_base_dir

    @logger = mock('logger')
    @logger.stub!(:info)
    Bosh::Agent::Config.logger = @logger

    @processor = Bosh::Agent::Message::Configure.new(nil)

    Bosh::Agent::Util.stub(:settings).and_return(complete_settings)

    # We just want to avoid this to accidently be invoked on dev systems
    #@processor.stub(:load_settings).and_return(complete_settings)
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
  it "should configure redis with bosh server settings data" do
    @processor.load_settings
    Bosh::Agent::Config.setup({"logging" => { "level" => "DEBUG" }, "redis" => {}, "blobstore" => {}})
    @processor.update_bosh_server
    redis_options = Bosh::Agent::Config.redis_options
    redis_options[:host].should == "172.30.40.11"
    redis_options[:port].should == "25255"
  end

  it "should configure blobstore with settings data" do
    @processor.load_settings
    Bosh::Agent::Config.setup({"logging" => { "level" => "DEBUG" }, "redis" => {}, "blobstore" => {}})
    @processor.update_blobstore
    blobstore_options = Bosh::Agent::Config.blobstore_options
    blobstore_options["user"].should == "agent"
  end

  it "should swap on data disk" do
    @processor.data_sfdisk_input.should == ",3859,S\n,,L\n"
  end

  def complete_settings
    settings_json = %q[{"vm":{"name":"vm-dbcbd32d-3756-44ea-8fdd-5d8cf7344d3d","id":"vm-51077"},"disks":{"ephemeral":1,"persistent":{"226":2},"system":0},"server":{"port":25255,"host":"172.30.40.11","password":"R3d!S"},"networks":{"network_a":{"netmask":"255.255.248.0","ip":"172.30.40.115","gateway":"172.30.40.1","dns":["172.30.22.153","172.30.22.154"],"cloud_properties":{"name":"VLAN440"}}},"blobstore":{"plugin":"simple","properties":{"password":"Ag3Nt","user":"agent","endpoint":"http://172.30.40.11:25250"}},"ntp":["ntp01.las01.emcatmos.com","ntp02.las01.emcatmos.com"],"agent_id":"f43aab8c-3435-484e-b1fc-73c56017c137"}]
    Yajl::Parser.new.parse(settings_json)
  end

end

