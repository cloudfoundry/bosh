require 'spec_helper'

describe 'CentOs Stemcell' do
  it_behaves_like 'a stemcell'

  describe package('apt') do
    it { should_not be_installed }
  end

  describe package('rpm') do
    it { should be_installed }
  end

  context 'installed by base_centos' do
    {
      'centos-release' => '6-4.el6.centos.10.x86_64',
      'epel-release'   => '6-8.noarch',
    }.each do |pkg, version|
      describe package(pkg) do
        it { should be_installed.with_version(version) }
      end
    end

    describe file('/etc/sysconfig/network') do
      it { should be_file }
    end
  end

  context 'installed by base_yum' do
    {
      'upstart'        => '0.6.5-12.el6_4.1.x86_64',
      'openssl-devel'  => '1.0.0-27.el6_4.2',
      'lsof'           => '4.82-4.el6.x86_64',
      'quota'          => '3.17-18.el6.x86_64',
      'rsync'          => '3.0.6-9.el6_4.1.x86_64',
      'strace'         => '4.5.19-1.17.el6.x86_64',
      'iptables'       => '1.4.7-9.el6.x86_64',
      'sysstat'        => '9.0.4-20.el6.x86_64',
      'tcpdump'        => '4.0.0-3.20090921gitdf3cb4.2.el6.x86_64',
      'dhclient'       => '4.1.1-34.P1.el6_4.1.x86_64',
      'zip'            => '3.0-1.el6.x86_64',
      'traceroute'     => '2.0.14-2.el6.x86_64',
      'gdb'            => '7.2-60.el6_4.1.x86_64',
      'curl'           => '7.19.7-37.el6_4.x86_64',
      'readline-devel' => '6.0-4.el6.x86_64',
      'flex'           => '2.5.35-8.el6.x86_64',
      'openssh-server' => '5.3p1-84.1.el6',
      'wget'           => '1.12-1.8.el6.x86_64',
      'libxml2'        => '2.7.6-12.el6_4.1.x86_64',
      'libxml2-devel'  => '2.7.6-12.el6_4.1.x86_64',
      'libxslt'        => '1.1.26-2.el6_3.1.x86_64',
      'libxslt-devel'  => '1.1.26-2.el6_3.1.x86_64',
      'psmisc'         => '22.6-15.el6_0.1.x86_64',
      'unzip'          => '6.0-1.el6.x86_64',
      'bison'          => '2.4.1-5.el6.x86_64',
      'libyaml'        => '0.1.3-1.el6.x86_64',
      'libyaml-devel'  => '0.1.3-1.el6.x86_64',
      'bzip2-devel'    => '1.0.5-7.el6_0.x86_64',
      'libcap-devel'   => '2.16-5.5.el6.x86_64',
      'cmake'          => '2.6.4-5.el6.x86_64',
      'rpm-build'      => '4.8.0-32.el6.x86_64',
      'rpmdevtools'    => '7.5-2.el6.noarch',
      'glibc-static'   => '2.12-1.107.el6_4.5.x86_64',
      'runit'          => '2.1.1-6.el6.x86_64',
      'sudo'           => '1.8.6p3-7.el6.x86_64',
      'libuuid-devel'  => '2.17.2-12.9.el6_4.3.x86_64',
      'nc'             => '1.84-22.el6.x86_64',
    }.each do |pkg, version|
      describe package(pkg) do
        it { should be_installed.with_version(version) }
      end
    end
  end

  context 'installed by system_grub' do
    {
      'grub' => '0.97-81.el6.x86_64',
    }.each do |pkg, version|
      describe package(pkg) do
        it { should be_installed.with_version(version) }
      end
    end

    %w(e2fs_stage1_5 stage1 stage2).each do |grub_stage|
      describe file("/boot/grub/#{grub_stage}") do
        it { should be_file }
      end
    end
  end

  context 'installed by system_kernel' do
    {
      'kernel'         => '2.6.32-358.23.2.el6.x86_64',
      'kernel-headers' => '2.6.32-358.23.2.el6.x86_64',
    }.each do |pkg, version|
      describe package(pkg) do
        it { should be_installed.with_version(version) }
      end
    end
  end

  context 'installed by image_install_grub' do
    describe file('/etc/fstab') do
      it { should be_file }
      it { should contain 'UUID=' }
      it { should contain '/ ext4 defaults 1 1' }
    end

    describe file('/boot/grub/grub.conf') do
      it { should be_file }
      it { should contain 'default=0' }
      it { should contain 'timeout=1' }
      it { should contain 'title CentOS release 6.4 (Final) (2.6.32-358.23.2.el6.x86_64)' }
      it { should contain '  root (hd0,0)' }
      it { should contain '  kernel /boot/vmlinuz-2.6.32-358.23.2.el6.x86_64 xen_blkfront.sda_is_xvda=1 ro root=UUID=' }
      it { should contain ' selinux=0' }
      it { should contain '  initrd /boot/initramfs-2.6.32-358.23.2.el6.x86_64.img' }
    end

    describe file('/boot/grub/menu.lst') do
      it { should be_linked_to('./grub.conf') }
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

    describe 'disallow root login' do
      subject { file('/etc/ssh/sshd_config') }

      it { should contain /^PermitRootLogin no$/ }
    end
  end

  context 'installed by system-aws-network', exclude_on_vsphere: true do
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

  context 'readahead-collector should be disabled' do
    describe file('/etc/sysconfig/readahead') do
      it { should be_file }
      it { should contain 'READAHEAD_COLLECT="no"' }
      it { should contain 'READAHEAD_COLLECT_ON_RPM="no"' }
    end
  end
end
