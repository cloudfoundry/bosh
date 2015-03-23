require 'spec_helper'

describe 'CentOS 7 stemcell', stemcell_image: true do
  context 'installed by image_install_grub', exclude_on_warden: true do

    # GRUB 2 configuration
    describe file('/boot/grub2/grub.cfg') do
      it { should contain 'net.ifnames=0' }
      it { should contain 'selinux=0' }
      it { should contain 'plymouth.enable=0' }
      it { should_not contain 'xen_blkfront.sda_is_xvda=1'}
    end

    # GRUB 0.97 configuration (used only on Amazon PV hosts) must have same kernel params as GRUB 2
    describe file('/boot/grub/grub.conf') do
      it { should contain 'net.ifnames=0' }
      it { should contain 'selinux=0' }
      it { should contain 'plymouth.enable=0' }
      it { should_not contain 'xen_blkfront.sda_is_xvda=1'}
    end
  end


  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/operating_system') do
      it { should contain('centos') }
    end
  end

  context 'installed by bosh_harden' do
    describe 'disallow unsafe setuid binaries' do
      subject { backend.run_command('find / -xdev -perm /6000 -a -type f')[:stdout].split }

      it { should match_array(%w(/usr/bin/su /usr/bin/sudo)) }
    end

    describe 'disallow root login' do
      subject { file('/etc/ssh/sshd_config') }

      it { should contain /^PermitRootLogin no$/ }
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

  context 'installed by bosh_openstack_agent_settings', {
    exclude_on_aws: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
  } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      it { should_not contain('"CreatePartitionIfNoEphemeralDisk": true') }
      it { should contain('"UseConfigDrive": true') }
    end
  end
end
