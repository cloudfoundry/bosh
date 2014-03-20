# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../../../spec_helper'

Bosh::Agent::Config.infrastructure_name = "vsphere"
Bosh::Agent::Config.infrastructure

describe Bosh::Agent::Infrastructure::Vsphere::Settings do
  subject(:settings) do
    Bosh::Agent::Infrastructure::Vsphere::Settings.new
  end

  let(:settings_json) do
    %q[{"vm":{"name":"vm-273a202e-eedf-4475-a4a1-66c6d2628742","id":"vm-51290"},"disks":{"ephemeral":1,"persistent":{"250":2},"system":0},"mbus":"nats://user:pass@11.0.0.11:4222","networks":{"network_a":{"netmask":"255.255.248.0","mac":"00:50:56:89:17:70","ip":"172.30.40.115","default":["gateway","dns"],"gateway":"172.30.40.1","dns":["172.30.22.153","172.30.22.154"],"cloud_properties":{"name":"VLAN440"}}},"blobstore":{"provider":"simple","options":{"password":"Ag3Nt","user":"agent","endpoint":"http://172.30.40.11:25250"}},"ntp":["ntp01.las01.emcatmos.com","ntp02.las01.emcatmos.com"],"agent_id":"a26efbe5-4845-44a0-9323-b8e36191a2c8"}]
  end

  context 'load settings from cdrom' do
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

      settings.stub(:load_vm_property)
      settings.send(:read_cdrom_byte)
    end

    it "should parse the /proc/sys/dev/cdrom/info with newline correctly" do
      File.should_receive(:read).with('/proc/sys/dev/cdrom/info').and_return(@proc_contents)
      settings.send(:cdrom_device).should eq "/dev/sr0"
    end

    it "should invoke commandline for /proc/sys/dev/cdrom/info just once" do
      File.should_receive(:read).with('/proc/sys/dev/cdrom/info').and_return(@proc_contents)
      settings.send(:cdrom_device).should eq "/dev/sr0"
      settings.send(:cdrom_device).should eq "/dev/sr0"
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
        settings.send(:check_cdrom)
      }.should raise_error(Bosh::Agent::LoadSettingsError)
    end

    it "should fail when cdrom is busy" do
      settings.stub(:read_cdrom_byte).and_raise(Errno::EBUSY)
      lambda {
        File.should_receive(:read).with('/proc/sys/dev/cdrom/info').and_return(@proc_contents)
        settings.send(:check_cdrom)
      }.should raise_error(Bosh::Agent::LoadSettingsError)
    end

    it 'should return nil when asked for network settings' do
      Bosh::Agent::Config.setup('infrastructure_name' => 'dummy')
      properties = Bosh::Agent::Config.infrastructure.get_network_settings("test", {})
      properties.should be_nil
    end

    describe '#check_cdrom' do
      context 'when udev settle returns 0' do
        before do
          settings.stub(:udevadm_settle)
        end

        it 'succeeds' do
          expect {
            settings.send(:check_cdrom)
          }.not_to raise_error
        end
      end

      context 'when udev settle returns 1' do
        before do
          settings.stub(:udevadm_settle).and_raise(Bosh::Exec::Error.new(1, '/sbin/udevadm settle'))
        end

        it 'wraps the error so Bosh::Agent::Settings can deal with it appropriately' do
          expect {
            settings.send(:check_cdrom)
          }.to raise_error(Bosh::Agent::LoadSettingsError)
        end
      end
    end
  end

  context 'load settings from VM property' do
    describe '#load_vm_property' do
      it 'reads json string from VM property and parses it successfully' do
        settings.should_receive(:vm_settings_property) { settings_json }
        settings.should_not_receive(:load_cdrom_settings)
        settings.load_settings.should == Yajl::Parser.new.parse(settings_json)
      end

      context 'vm_settings_property is not available' do
        it 'returns nil' do
          settings.should_receive(:vm_settings_property)
          settings.send(:load_vm_property).should be_nil
        end
      end

      context 'vm_settings_property is invalid' do
        it 'raises LoadSettingsError' do
          settings.should_receive(:vm_settings_property) { 'dummy' }
          settings.should_not_receive(:load_cdrom_settings)
          expect do
            settings.load_settings
          end.to raise_exception Bosh::Agent::LoadSettingsError,
                                 'Failed to parse settings_json dummy'
        end
      end
    end

    describe '#vm_settings_property' do
      let(:ovf_info) do
        <<-ovf_info
<?xml version="1.0" encoding="UTF-8"?>
<Environment
     xmlns="http://schemas.dmtf.org/ovf/environment/1"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xmlns:oe="http://schemas.dmtf.org/ovf/environment/1"
     xmlns:ve="http://www.vmware.com/schema/ovfenv"
     oe:id=""
     ve:vCenterId="vm-22824">
   <PlatformSection>
      <Kind>VMware ESXi</Kind>
      <Version>5.0.0</Version>
      <Vendor>VMware, Inc.</Vendor>
      <Locale>en</Locale>
   </PlatformSection>
   <PropertySection>
         <Property oe:key="DNS" oe:value="10.146.17.124"/>
         <Property oe:key="admin_password" oe:value="tempest"/>
         <Property oe:key="gateway" oe:value="10.146.17.253"/>
         <Property oe:key="ip0" oe:value="10.146.17.135"/>
         <Property oe:key="netmask0" oe:value="255.255.255.128"/>
         <Property oe:key="ntp_servers" oe:value="ntp1-pao11.eng.vmware.com"/>
         <Property oe:key="agent_env_settings" oe:value="#{settings_json.gsub(/"/, '&quot;')}"/>
   </PropertySection>
   <ve:EthernetAdapterSection>
      <ve:Adapter ve:mac="00:50:56:b4:43:1b" ve:network="VM Network" ve:unitNumber="7"/>
   </ve:EthernetAdapterSection>
</Environment>
        ovf_info
      end
      let(:cmd) { "vmtoolsd --cmd 'info-get guestinfo.ovfEnv' 2>&1" }
      let(:result) { Bosh::Exec::Result.new(cmd, ovf_info, 0) }
      before do
        Bosh::Exec.should_receive(:sh).with(cmd, on_error: :return).and_return(result)
      end

      it 'reads JSON settings from VM property' do
        subject.send(:vm_settings_property).should == settings_json
      end

      context 'Failed to run vmtoolsd' do
        let(:result) { Bosh::Exec::Result.new(cmd, 'No value found', 1) }
        it 'returns nil' do
          subject.send(:vm_settings_property).should be_nil
        end
      end

      context 'No settings_node with key agent_env_settings is found' do
        let(:ovf_info) do
          <<-ovf_info
<?xml version="1.0" encoding="UTF-8"?>
<Environment
     xmlns="http://schemas.dmtf.org/ovf/environment/1"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xmlns:oe="http://schemas.dmtf.org/ovf/environment/1"
     xmlns:ve="http://www.vmware.com/schema/ovfenv"
     oe:id=""
     ve:vCenterId="vm-22824">
   <PlatformSection>
      <Kind>VMware ESXi</Kind>
      <Version>5.0.0</Version>
      <Vendor>VMware, Inc.</Vendor>
      <Locale>en</Locale>
   </PlatformSection>
   <PropertySection>
         <Property oe:key="DNS" oe:value="10.146.17.124"/>
         <Property oe:key="admin_password" oe:value="tempest"/>
         <Property oe:key="gateway" oe:value="10.146.17.253"/>
         <Property oe:key="ip0" oe:value="10.146.17.135"/>
         <Property oe:key="netmask0" oe:value="255.255.255.128"/>
         <Property oe:key="ntp_servers" oe:value="ntp1-pao11.eng.vmware.com"/>
   </PropertySection>
   <ve:EthernetAdapterSection>
      <ve:Adapter ve:mac="00:50:56:b4:43:1b" ve:network="VM Network" ve:unitNumber="7"/>
   </ve:EthernetAdapterSection>
</Environment>
          ovf_info
        end

        it 'returns nil' do
          subject.send(:vm_settings_property).should be_nil
        end
      end

      context 'agent_env_settings xml node value is empty' do
        let(:ovf_info) do
          <<-ovf_info
<?xml version="1.0" encoding="UTF-8"?>
<Environment
     xmlns="http://schemas.dmtf.org/ovf/environment/1"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xmlns:oe="http://schemas.dmtf.org/ovf/environment/1"
     xmlns:ve="http://www.vmware.com/schema/ovfenv"
     oe:id=""
     ve:vCenterId="vm-22824">
   <PlatformSection>
      <Kind>VMware ESXi</Kind>
      <Version>5.0.0</Version>
      <Vendor>VMware, Inc.</Vendor>
      <Locale>en</Locale>
   </PlatformSection>
   <PropertySection>
         <Property oe:key="DNS" oe:value="10.146.17.124"/>
         <Property oe:key="admin_password" oe:value="tempest"/>
         <Property oe:key="gateway" oe:value="10.146.17.253"/>
         <Property oe:key="ip0" oe:value="10.146.17.135"/>
         <Property oe:key="netmask0" oe:value="255.255.255.128"/>
         <Property oe:key="ntp_servers" oe:value="ntp1-pao11.eng.vmware.com"/>
         <Property oe:key="agent_env_settings" oe:value="  "/>
   </PropertySection>
   <ve:EthernetAdapterSection>
      <ve:Adapter ve:mac="00:50:56:b4:43:1b" ve:network="VM Network" ve:unitNumber="7"/>
   </ve:EthernetAdapterSection>
</Environment>
          ovf_info
        end

        it 'raises LoadSettingsError' do
          expect do
            subject.send(:vm_settings_property)
          end.to raise_exception Bosh::Agent::LoadSettingsError,
                                 'agent_env_settings xml node value is empty!'
        end
      end
    end
  end
end
