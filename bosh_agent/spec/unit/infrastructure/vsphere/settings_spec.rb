# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../../../spec_helper'

Bosh::Agent::Config.infrastructure_name = "vsphere"
Bosh::Agent::Config.infrastructure

describe Bosh::Agent::Infrastructure::Vsphere::Settings do
  subject(:settings) do
    Bosh::Agent::Infrastructure::Vsphere::Settings.new
  end
  
  before do
    @proc_contents = <<-eos
CD-ROM information, Id: cdrom.c 3.20 2003/12/17

drive name:		sr0
drive speed:		24
drive # of slots:	1
Can close tray:		1
Can open tray:		1
Can lock tray:		1
Can change speed:	1
Can select disk:	0
Can read multisession:	1
Can read MCN:		1
Reports media changed:	1
Can play audio:		1
Can write CD-R:		1
Can write CD-RW:	1
Can read DVD:		1
Can write DVD-R:	1
Can write DVD-RAM:	1
Can read MRW:		1
Can write MRW:		1
Can write RAM:		1
eos
    
    settings.cdrom_retry_wait = 0.1

    settings.stub(:mount_cdrom)
    settings.stub(:umount_cdrom)
    settings.stub(:eject_cdrom)
    settings.stub(:udevadm_settle)
    settings.stub(:read_cdrom_byte)

    settings.read_cdrom_byte
  end

  it "should parse the /proc/sys/dev/cdrom/info with newline correctly" do
    File.should_receive(:read).with('/proc/sys/dev/cdrom/info').and_return(@proc_contents)
    settings.cdrom_device.should eq "/dev/sr0"
  end

  it "should invoke commandline for /proc/sys/dev/cdrom/info just once" do
    File.should_receive(:read).with('/proc/sys/dev/cdrom/info').and_return(@proc_contents)
    settings.cdrom_device.should eq "/dev/sr0"
    settings.cdrom_device.should eq "/dev/sr0"
  end

  it 'should load settings' do
    cdrom_dir = File.join(base_dir, 'bosh', 'settings')
    env = File.join(cdrom_dir, 'env')

    FileUtils.mkdir_p(cdrom_dir)
    File.open(env, 'w') { |f| f.write(settings_json) }

    settings.load_settings.should == Yajl::Parser.new.parse(settings_json)
  end

  it "should fail when there is no cdrom" do
    settings.stub(:read_cdrom_byte).and_raise(Errno::ENOMEDIUM)
    lambda {
      File.should_receive(:read).with('/proc/sys/dev/cdrom/info').and_return(@proc_contents)
      settings.check_cdrom
    }.should raise_error(Bosh::Agent::LoadSettingsError)
  end

  it "should fail when cdrom is busy" do
    settings.stub(:read_cdrom_byte).and_raise(Errno::EBUSY)
    lambda {
      File.should_receive(:read).with('/proc/sys/dev/cdrom/info').and_return(@proc_contents)
      settings.check_cdrom
    }.should raise_error(Bosh::Agent::LoadSettingsError)
  end

  it 'should return nil when asked for network settings' do
    Bosh::Agent::Config.setup('infrastructure_name' => 'dummy')
    properties = Bosh::Agent::Config.infrastructure.get_network_settings("test", {})
    properties.should be_nil
  end

  def settings_json
    %q[{"vm":{"name":"vm-273a202e-eedf-4475-a4a1-66c6d2628742","id":"vm-51290"},"disks":{"ephemeral":1,"persistent":{"250":2},"system":0},"mbus":"nats://user:pass@11.0.0.11:4222","networks":{"network_a":{"netmask":"255.255.248.0","mac":"00:50:56:89:17:70","ip":"172.30.40.115","default":["gateway","dns"],"gateway":"172.30.40.1","dns":["172.30.22.153","172.30.22.154"],"cloud_properties":{"name":"VLAN440"}}},"blobstore":{"provider":"simple","options":{"password":"Ag3Nt","user":"agent","endpoint":"http://172.30.40.11:25250"}},"ntp":["ntp01.las01.emcatmos.com","ntp02.las01.emcatmos.com"],"agent_id":"a26efbe5-4845-44a0-9323-b8e36191a2c8"}]
  end

  describe '#check_cdrom' do
    context 'when udev settle returns 0' do
      before do
        settings.stub(:udevadm_settle)
      end

      it 'succeeds' do
        expect {
          settings.check_cdrom
        }.not_to raise_error
      end
    end

    context 'when udev settle returns 1' do
      before do
        settings.stub(:udevadm_settle).and_raise(Bosh::Exec::Error.new(1, '/sbin/udevadm settle'))
      end

      it 'wraps the error so Bosh::Agent::Settings can deal with it appropriately' do
        expect {
          settings.check_cdrom
        }.to raise_error(Bosh::Agent::LoadSettingsError)
      end
    end
  end
end
