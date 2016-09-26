shared_examples_for 'a CentOS 7 or RHEL 7 stemcell' do

  describe command('ls -1 /lib/modules | wc -l') do
    its(:stdout) {should eq "1\n"}
  end

  context 'installed by image_install_grub' do
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
      it('single-user mode boot should be disabled (stig: V-38586)') { should_not contain 'single' }

      it('should set the user name and password for grub menu (stig: V-38585)') { should contain 'set superusers=vcap' }
      it('should set the user name and password for grub menu (stig: V-38585)') { should contain /^password_pbkdf2 vcap grub.pbkdf2.sha512.*/ }

      it('should be of mode 600 (stig: V-38583)') { should be_mode('600') }
      it('should be owned by root (stig: V-38579)') { should be_owned_by('root') }
      it('should be grouped into root (stig: V-38581)') { should be_grouped_into('root') }
    end

    # GRUB 0.97 configuration (used only on Amazon PV hosts) must have same kernel params as GRUB 2
    describe file('/boot/grub/grub.conf') do
      it { should contain 'net.ifnames=0' }
      it { should contain 'selinux=0' }
      it { should contain 'plymouth.enable=0' }
      it { should_not contain 'xen_blkfront.sda_is_xvda=1'}

      it('should be of mode 600 (stig: V-38583)') { should be_mode('600') }
      it('should be owned by root (stig: V-38579)') { should be_owned_by('root') }
      it('should be grouped into root (stig: V-38581)') { should be_grouped_into('root') }
      it('audits processes that start prior to auditd (CIS-8.1.3)') { should contain ' audit=1' }
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

  context 'installed by system-network on all IaaSes', { exclude_on_warden: true } do
    describe file('/etc/hostname') do
      it { should be_file }
      its (:content) { should eq('bosh-stemcell') }
    end
  end

  context 'installed by the system_network stage', {
    exclude_on_warden: true,
    exclude_on_azure: true,
  } do
    describe file('/etc/sysconfig/network') do
      it { should be_file }
      it { should contain 'NETWORKING=yes' }
      it { should contain 'NETWORKING_IPV6=no' }
      it { should contain 'HOSTNAME=bosh-stemcell' }
      it { should contain 'NOZEROCONF=yes' }
    end

    describe file('/etc/NetworkManager/NetworkManager.conf') do
      it { should be_file }
      it { should contain 'plugins=ifcfg-rh' }
      it { should contain 'no-auto-default=*' }
    end
  end

  context 'installed by the system_azure_network stage', {
    exclude_on_aws: true,
    exclude_on_google: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
    exclude_on_openstack: true,
  } do
    describe file('/etc/sysconfig/network') do
      it { should be_file }
      it { should contain 'NETWORKING=yes' }
      it { should contain 'NETWORKING_IPV6=no' }
      it { should contain 'HOSTNAME=bosh-stemcell' }
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

  context 'installed by bosh_aws_agent_settings', {
    exclude_on_google: true,
    exclude_on_openstack: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
    exclude_on_azure: true,
  } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      it { should contain('"Type": "HTTP"') }
    end
  end

  context 'installed by bosh_google_agent_settings', {
    exclude_on_aws: true,
    exclude_on_openstack: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
    exclude_on_azure: true,
  } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      it { should contain('"Type": "InstanceMetadata"') }
    end
  end

  context 'installed by bosh_vsphere_agent_settings', {
    exclude_on_aws: true,
    exclude_on_google: true,
    exclude_on_vcloud: true,
    exclude_on_openstack: true,
    exclude_on_warden: true,
    exclude_on_azure: true,
   } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      it { should contain('"Type": "CDROM"') }
    end
  end

  context 'installed by bosh_azure_agent_settings', {
    exclude_on_aws: true,
    exclude_on_google: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
    exclude_on_openstack: true,
  } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      it { should contain('"Type": "File"') }
      it { should contain('"MetaDataPath": ""') }
      it { should contain('"UserDataPath": "/var/lib/waagent/CustomData"') }
      it { should contain('"SettingsPath": "/var/lib/waagent/CustomData"') }
      it { should contain('"UseServerName": true') }
      it { should contain('"UseRegistry": true') }
    end
  end
end
