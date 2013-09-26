require 'spec_helper'

describe 'CentOs Stemcell' do
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
      'rsync'          => '3.0.6-9.el6.x86_64',
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
      'cmake'          => '2.6.4-5.el6.x86_64',
      'rpm-build'      => '4.8.0-32.el6.x86_64',
      'rpmdevtools'    => '7.5-2.el6.noarch',
      'glibc-static'   => '2.12-1.107.el6_4.4.x86_64',
      'runit'          => '2.1.1-6.el6.x86_64',
      'sudo'           => '1.8.6p3-7.el6.x86_64',
      'rsyslog'        => '5.8.10-7.el6_4.x86_64',
      'rsyslog-relp'   => '5.8.10-7.el6_4.x86_64',
    }.each do |pkg, version|
      describe package(pkg) do
        it { should be_installed.with_version(version) }
      end
    end
  end

  describe 'installed by bosh_ruby' do
    describe command('/var/vcap/bosh/bin/ruby -r yaml -e "Psych::SyntaxError"') do
      it { should return_exit_status(0) }
    end
  end

  describe 'installed by bosh_agent' do
    describe command('/var/vcap/bosh/bin/ruby -r bosh_agent -e"Bosh::Agent"') do
      it { should return_exit_status(0) }
    end
  end

  context 'installed by bosh_sudoers' do
    describe file('/etc/sudoers') do
      it { should be_file }
      it { should contain '#includedir /etc/sudoers.d' }
    end
  end

  context 'installed by bosh_micro' do
    describe file('/var/vcap/micro/apply_spec.yml') do
      it { should be_a_file }
      it { should contain 'powerdns' }
    end

    describe file('/var/vcap/micro_bosh/data/cache') do
      it { should be_a_directory }
    end
  end

  context 'installed by system_grub'

  context 'installed by system_kernel'

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
      it { should contain 'title CentOS release 6.4 (Final) (2.6.32-358.18.1.el6.x86_64)' }
      it { should contain '  root (hd0,0)' }
      it { should contain '  kernel /boot/vmlinuz-2.6.32-358.18.1.el6.x86_64 ro root=UUID=' }
      it { should contain '  initrd /boot/initramfs-2.6.32-358.18.1.el6.x86_64.img' }
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
end
