require File.dirname(__FILE__) + '/../spec_helper'
require 'fakefs/spec_helpers'

describe Bosh::Agent::Bootstrap do
  let(:dummy_platform) { instance_double('Bosh::Agent::Platform::Linux::Adapter') }

  before do
    Bosh::Agent::Config.infrastructure_name = "dummy"
    Bosh::Agent::Config.stub(platform: dummy_platform)
    Bosh::Agent::Config.platform_name = "dummy"

    @processor = Bosh::Agent::Bootstrap.new

    Bosh::Agent::Util.stub(:block_device_size).and_return(7903232)
    Bosh::Agent::Config.infrastructure.stub(:load_settings).and_return(complete_settings)
    Bosh::Agent::Config.platform.stub(:get_data_disk_device_name).and_return("/dev/dummy")
    Bosh::Agent::Config.settings_file = File.join(base_dir, 'bosh', 'settings.json')

    # We just want to avoid this to accidently be invoked on dev systems
    Bosh::Agent::Util.stub(:update_file)
    @processor.stub(:partition_disk)
    @processor.stub(:mem_total).and_return(3951616)
  end

  it 'run configuration steps in a specific order' do
    Bosh::Agent::Config.stub(configure: true)

    @processor.should_receive(:update_iptables).ordered
    @processor.should_receive(:update_passwords).ordered
    @processor.should_receive(:update_agent_id).ordered
    @processor.should_receive(:update_credentials).ordered
    @processor.should_receive(:update_hostname).ordered
    @processor.should_receive(:update_mbus).ordered
    @processor.should_receive(:update_blobstore).ordered
    @processor.should_receive(:setup_networking).ordered
    @processor.should_receive(:update_time).ordered
    @processor.should_receive(:setup_data_disk).ordered
    @processor.should_receive(:setup_data_sys).ordered
    @processor.should_receive(:setup_tmp).ordered

    Bosh::Agent::Monit.should_receive(:setup_monit_user).ordered
    Bosh::Agent::Monit.should_receive(:setup_alerts).ordered

    @processor.should_receive(:mount_persistent_disk).ordered
    @processor.should_receive(:harden_permissions).ordered

    @processor.configure
  end

  it "should update credentials" do
    @processor.load_settings
    @processor.update_credentials
    Bosh::Agent::Config.credentials.should == nil

    new_settings = complete_settings
    new_settings["env"] ||= {}
    new_settings["env"]["bosh"] ||= {}
    new_settings["env"]["bosh"]["credentials"] = {"crypt_key"=>"crypt_key", "sign_key"=>"sign_key"}

    Bosh::Agent::Config.infrastructure.stub(:load_settings).and_return(new_settings)

    @processor.load_settings
    @processor.update_credentials
    Bosh::Agent::Config.credentials.should == {"crypt_key"=>"crypt_key", "sign_key"=>"sign_key"}
  end

  it "should not setup iptables without settings" do
    @processor.load_settings
    @processor.stub(:iptables).and_raise(Bosh::Agent::Error)
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

  describe "#setup_data_disk" do
    let(:data_disk) { "/dev/sdx" }

    context "with ephemeral disk" do
      before(:each) do
        Bosh::Agent::Config.platform.stub(:get_data_disk_device_name => data_disk)
        File.stub(:blockdev?).with(data_disk).and_return(true)
        @processor.stub(:setup_data_sys)
      end

      context "format disk" do
        before do
          Bosh::Agent::Config.settings = {}
        end

        context "without anything mounted or formatted" do

          before do
            swap_result = Bosh::Exec::Result.new("cat /proc/swaps | grep #{data_disk}1", '',1)
            @processor.should_receive(:sh).with("cat /proc/swaps | grep #{data_disk}1", :on_error => :return).and_return(swap_result)
            mount_result = Bosh::Exec::Result.new("mount | grep #{data_disk}2", '',1)
            @processor.should_receive(:sh).with("mount | grep #{data_disk}2", :on_error => :return).and_return(mount_result)
          end

          it "should partition the disk with one data and one swap partition (with lazy_itable_init)" do
            Bosh::Agent::Util.should_receive(:partition_disk) do |disk, _|
              disk.should == data_disk
            end
            Bosh::Agent::Util.should_receive(:lazy_itable_init_enabled?).and_return(true)

            @processor.should_receive(:sh).with("mkswap #{data_disk}1")
            @processor.should_receive(:sh).with("/sbin/mke2fs -t ext4 -j -E lazy_itable_init=1 #{data_disk}2")
            @processor.should_receive(:sh).with("swapon #{data_disk}1")

            FileUtils.stub(:mkdir_p)
            @processor.should_receive(:sh).with(%r[mount #{data_disk}2 .+/data])
  
            @processor.setup_data_disk
          end
  
          it "should partition the disk with one data and one swap partition (without lazy_itable_init)" do
            Bosh::Agent::Util.should_receive(:partition_disk) do |disk, _|
              disk.should == data_disk
            end
            Bosh::Agent::Util.should_receive(:lazy_itable_init_enabled?).and_return(false)
  
            @processor.should_receive(:sh).with("mkswap #{data_disk}1")
            @processor.should_receive(:sh).with("/sbin/mke2fs -t ext4 -j #{data_disk}2")
            @processor.should_receive(:sh).with("swapon #{data_disk}1")
  
            FileUtils.stub(:mkdir_p)
            @processor.should_receive(:sh).with(%r[mount #{data_disk}2 .+/data])
  
            @processor.setup_data_disk
          end
        end
  
        context "with swap mounted" do
  
          before do
            swap_result = Bosh::Exec::Result.new("cat /proc/swaps | grep #{data_disk}1", '/dev/xvdb1                              partition	1702884	0	-1',0)
            @processor.should_receive(:sh).with("cat /proc/swaps | grep #{data_disk}1", :on_error => :return).and_return(swap_result)
            mount_result = Bosh::Exec::Result.new("mount | grep #{data_disk}2", '',2)
            @processor.should_receive(:sh).with("mount | grep #{data_disk}2", :on_error => :return).and_return(mount_result)
            Dir.should_receive(:glob).with("#{data_disk}[1-2]").and_return(["#{data_disk}1", "#{data_disk}2"])
          end
  
          it 'should skip the swapon' do
  
            @processor.should_not_receive(:sh).with("mkswap #{data_disk}1")
            @processor.should_not_receive(:sh).with("/sbin/mke2fs -t ext4 -j #{data_disk}2")
            @processor.should_not_receive(:sh).with("swapon #{data_disk}1")
  
            FileUtils.stub(:mkdir_p)
            @processor.should_receive(:sh).with(%r[mount #{data_disk}2 .+/data])
  
            @processor.setup_data_disk
          end
        end
  
        context "with data partition mounted" do
  
          before do
            swap_result = Bosh::Exec::Result.new("cat /proc/swaps | grep #{data_disk}1",'',1)
            @processor.should_receive(:sh).with("cat /proc/swaps | grep #{data_disk}1", :on_error => :return).and_return(swap_result)
            mount_result = Bosh::Exec::Result.new("mount | grep #{data_disk}2", '/dev/xvdb2 on /var/vcap/data type ext4 (rw)',0)
            @processor.should_receive(:sh).with("mount | grep #{data_disk}2", :on_error => :return).and_return(mount_result)
            Dir.should_receive(:glob).with("#{data_disk}[1-2]").and_return(["#{data_disk}1", "#{data_disk}2"])
          end
  
          it 'should skip the data partition format and mount' do
  
            @processor.should_not_receive(:sh).with("mkswap #{data_disk}1")
            @processor.should_not_receive(:sh).with("/sbin/mke2fs -t ext4 -j #{data_disk}2")
  
            @processor.should_receive(:sh).with("swapon #{data_disk}1")
  
            FileUtils.stub(:mkdir_p)
            @processor.should_not_receive(:sh).with(%r[mount #{data_disk}2 .+/data])
  
            @processor.setup_data_disk
          end
        end
      end
    end

    context "without ephemeral disk" do
      before(:each) do
        Bosh::Agent::Config.platform.stub(:get_data_disk_device_name => nil)
      end

      it 'should setup data sys' do
        FileUtils.stub(:mkdir_p)
        @processor.should_not_receive(:sh)
        @processor.setup_data_disk
      end
    end
  end

  describe '#setup_data_sys' do
    include FakeFS::SpecHelpers

    before do
      Bosh::Agent::Config.setup(
        'logging' => { 'file' => StringIO.new },
        'base_dir' => base_dir,
      )
    end

    before { Etc.stub(:getgrnam).with('vcap').and_return(double(gid: 42)) }

    before { Bosh::Agent::Util.stub(:create_symlink) }

    let(:base_dir) { '/tmp/somedir' }
    let(:dummy_dir_path) { '/tmp/canary_dir' }
    let(:canary_dir_mode) do
      dir = Dir.mktmpdir('dummy_dir')
      FileUtils.chmod(0750, dir)
      File.stat(dir).mode
    end

    it 'symlinks sys to data/sys' do
      # Ruby's ln_sf is broken see .create_symlink for details
      Bosh::Agent::Util
        .should_receive(:create_symlink)
        .with('/tmp/somedir/data/sys', '/tmp/somedir/sys')
      @processor.setup_data_sys
    end

    %w(log run).each do |dir|
      describe "#{dir} dir" do
        it "creates a data/sys/#{dir} directory" do
          path = "/tmp/somedir/data/sys/#{dir}"
          @processor.setup_data_sys
          expect(File.directory?(path)).to be(true)
          expect(File.stat(path).gid).to eq(42)
          expect(File.stat(path).mode).to eq(canary_dir_mode)
        end
      end
    end
  end

  def complete_settings
    settings_json = %q[{"vm":{"name":"vm-273a202e-eedf-4475-a4a1-66c6d2628742","id":"vm-51290"},"disks":{"ephemeral":1,"persistent":{"250":2},"system":0},"mbus":"nats://user:pass@11.0.0.11:4222","networks":{"network_a":{"netmask":"255.255.248.0","mac":"00:50:56:89:17:70","ip":"172.30.40.115","default":["gateway","dns"],"gateway":"172.30.40.1","dns":["172.30.22.153","172.30.22.154"],"cloud_properties":{"name":"VLAN440"}}},"blobstore":{"provider":"simple","options":{"password":"Ag3Nt","user":"agent","endpoint":"http://172.30.40.11:25250"}},"ntp":["ntp01.las01.emcatmos.com","ntp02.las01.emcatmos.com"],"agent_id":"a26efbe5-4845-44a0-9323-b8e36191a2c8"}]
    Yajl::Parser.new.parse(settings_json)
  end

end
