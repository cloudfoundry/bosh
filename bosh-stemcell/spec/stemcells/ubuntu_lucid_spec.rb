require 'spec_helper'

describe 'Ubuntu Lucid stemcell' do
  context 'installed by image_install_grub', exclude_on_warden: true do
    describe file('/boot/grub/grub.conf') do
      it { should be_file }
      it { should contain 'default=0' }
      it { should contain 'timeout=1' }
      it { should contain 'title Ubuntu 10.04.4 LTS (3.0.0-32-virtual)' }
      it { should contain '  root (hd0,0)' }
      it { should contain '  kernel /boot/vmlinuz-3.0.0-32-virtual ro root=UUID=' }
      it { should contain ' selinux=0' }
      it { should contain ' cgroup_enable=memory swapaccount=1' }
      it { should contain '  initrd /boot/initrd.img-3.0.0-32-virtual' }
    end

    describe file('/boot/grub/menu.lst') do
      before { pending 'until aws/openstack stop clobbering the symlink with "update-grub"' }
      it { should be_linked_to('./grub.conf') }
    end
  end

  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/operating_system') do
      it { should contain('ubuntu') }
    end
  end

  context 'installed by bosh_harden' do
    describe 'disallow unsafe setuid binaries' do
      subject { backend.run_command('find / -xdev -perm +6000 -a -type f')[:stdout].split }

      it { should match_array(%w(/bin/su /usr/bin/sudo /usr/bin/sudoedit)) }
    end

    describe 'disallow root login' do
      subject { file('/etc/ssh/sshd_config') }

      it { should contain /^PermitRootLogin no$/ }
    end
  end

  context 'with system-aws-network', {
    exclude_on_vsphere: true,
    exclude_on_vcloud: true,
    exclude_on_warden: true,
  } do
    describe file('/etc/network/interfaces') do
      it { should be_file }
      it { should contain 'auto eth0' }
      it { should contain 'iface eth0 inet dhcp' }
    end
  end
end
