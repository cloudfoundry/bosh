require 'spec_helper'

describe 'CentOS 6.x stemcell', stemcell_image: true do

  it_behaves_like 'All Stemcells'
  
  context 'installed by image_install_grub', exclude_on_warden: true do
    describe file('/etc/fstab') do
      it { should be_file }
      it { should contain 'UUID=' }
      it { should contain '/ ext4 defaults 1 1' }
    end

    describe file('/boot/grub/grub.conf') do
      it { should be_file }
      it { should contain 'default=0' }
      it { should contain 'timeout=1' }
      it { should contain 'title CentOS release 6.6 (Final) ' }
      it { should contain '  root (hd0,0)' }
      it { should contain ' xen_blkfront.sda_is_xvda=1' }
      it { should contain ' ro root=UUID=' }
      it { should contain ' selinux=0' }
      it { should contain ' console=tty0 console=ttyS0,115200n8' }

      it { should_not contain 'net.ifnames=0' }
      it { should_not contain 'plymouth.enable=0' }
    end

    describe file('/boot/grub/menu.lst') do
      it { should be_linked_to('./grub.conf') }
    end

    describe file("/boot/grub/e2fs_stage1_5") do
      it { should be_file }
    end

    describe file('/boot/grub/grub.conf') do
    end
  end

  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/operating_system') do
      it { should contain('centos') }
    end
  end

  context 'installed by bosh_harden' do
    describe 'disallow unsafe setuid binaries' do
      subject { backend.run_command('find / -xdev -perm +6000 -a -type f')[:stdout].split }

      it { should match_array(%w(/bin/su /usr/bin/sudo)) }
    end
  end

  context 'with system-aws-network', exclude_on_vsphere: true, exclude_on_vcloud: true, exclude_on_warden: true do
    describe file('/etc/sysconfig/network') do
      it { should be_file }
      it { should contain 'NETWORKING=yes' }
      it { should contain 'NETWORKING_IPV6=no' }
      it { should contain 'HOSTNAME=localhost.localdomain' }
      it { should contain 'NOZEROCONF=yes' }
    end

    describe file('/etc/sysconfig/network-scripts/ifcfg-eth0') do
      it { should be_file }
      it { should contain 'DEVICE=eth0' }
      it { should contain 'BOOTPROTO=dhcp' }
      it { should contain 'ONBOOT=on' }
      it { should contain 'TYPE="Ethernet"' }
    end
  end

  context 'installed by image_vsphere_cdrom stage', {
    exclude_on_aws: true,
    exclude_on_vcloud: true,
    exclude_on_warden: true,
    exclude_on_openstack: true,
  } do
    describe file('/etc/sysctl.conf') do
      it { should be_file }
      it { should contain 'dev.cdrom.lock=0' }
    end
  end

  context 'installed by bosh_aws_agent_settings', {
    exclude_on_openstack: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
  } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      it { should contain('"Type": "HTTP"') }
    end
  end

  context 'installed by bosh_openstack_agent_settings', {
    exclude_on_aws: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
  } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      it { should_not contain('"CreatePartitionIfNoEphemeralDisk": true') }
      it { should contain('"Type": "ConfigDrive"') }
      it { should contain('"Type": "HTTP"') }
    end
  end

  context 'installed by bosh_vsphere_agent_settings', {
      exclude_on_aws: true,
      exclude_on_vcloud: true,
      exclude_on_openstack: true,
      exclude_on_warden: true,
    } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      it { should contain('"Type": "CDROM"') }
    end
  end
end
