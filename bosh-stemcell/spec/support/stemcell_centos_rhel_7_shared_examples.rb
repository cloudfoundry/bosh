shared_examples_for 'a CentOS 7 or RHEL 7 stemcell' do

  context 'installed by image_install_grub', exclude_on_warden: true do
    describe file('/etc/fstab') do
      it { should be_file }
      it { should contain 'UUID=' }
      it { should contain '/ ext4 defaults 1 1' }
    end

    # GRUB 2 configuration
    describe file('/boot/grub2/grub.cfg') do
      it { should contain 'net.ifnames=0' }
      it { should contain 'selinux=0' }
      it { should contain 'plymouth.enable=0' }
      it { should_not contain 'xen_blkfront.sda_is_xvda=1'}
      # single-user mode boot should be disabled (stig: V-38586)
      it { should_not contain 'single' }
    end

    # GRUB 0.97 configuration (used only on Amazon PV hosts) must have same kernel params as GRUB 2
    describe file('/boot/grub/grub.conf') do
      it { should contain 'net.ifnames=0' }
      it { should contain 'selinux=0' }
      it { should contain 'plymouth.enable=0' }
      it { should_not contain 'xen_blkfront.sda_is_xvda=1'}
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

  context 'installed by the system_network stage', exclude_on_warden: true do
    describe file('/etc/sysconfig/network') do
      it { should be_file }
      it { should contain 'NETWORKING=yes' }
      it { should contain 'NETWORKING_IPV6=no' }
      it { should contain 'HOSTNAME=localhost.localdomain' }
      it { should contain 'NOZEROCONF=yes' }
    end

    describe file('/etc/NetworkManager/NetworkManager.conf') do
      it { should be_file }
      it { should contain 'plugins=ifcfg-rh' }
      it { should contain 'no-auto-default=*' }
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
