require 'spec_helper'

describe 'Ubuntu Stemcell' do

  it_behaves_like 'a stemcell'

  describe package('apt') do
    it { should be_installed }
  end

  describe package('rpm') do
    it { should_not be_installed }
  end

  context 'installed by base_debootstrap' do
    {
      'ubuntu-minimal' => '1.197',
    }.each do |pkg, version|
      describe package(pkg) do
        it { should be_installed.with_version(version) }
      end
    end

    describe file('/etc/lsb-release') do
      it { should be_file }
      it { should contain 'DISTRIB_RELEASE=10.04' }
      it { should contain 'DISTRIB_CODENAME=lucid' }
    end
  end

  context 'installed by base_apt' do
    {
      'upstart'              => '0.6.5-8',
      'build-essential'      => '11.4build1',
      'libssl-dev'           => '0.9.8k-7ubuntu8.15',
      'lsof'                 => '4.81.dfsg.1-1build1',
      'strace'               => '4.5.19-2',
      'bind9-host'           => '1:9.7.0.dfsg.P1-1ubuntu0.10',
      'dnsutils'             => '1:9.7.0.dfsg.P1-1ubuntu0.10',
      'tcpdump'              => '4.0.0-6ubuntu3',
      'iputils-arping'       => '3:20071127-2ubuntu1',
      'curl'                 => '7.19.7-1ubuntu1.3',
      'wget'                 => '1.12-1.1ubuntu2.1',
      'libcurl3'             => '7.19.7-1ubuntu1.3',
      'libcurl4-openssl-dev' => '7.19.7-1ubuntu1.3', # installed because of 'libcurl3-dev'
      'bison'                => '1:2.4.1.dfsg-3',
      'libreadline6-dev'     => '6.1-1',
      'libxml2'              => '2.7.6.dfsg-1ubuntu1.10',
      'libxml2-dev'          => '2.7.6.dfsg-1ubuntu1.10',
      'libxslt1.1'           => '1.1.26-1ubuntu1.2',
      'libxslt1-dev'         => '1.1.26-1ubuntu1.2',
      'zip'                  => '3.0-2',
      'unzip'                => '6.0-1build1',
      'nfs-common'           => '1:1.2.0-4ubuntu4.2',
      'flex'                 => '2.5.35-9',
      'psmisc'               => '22.10-1',
      'apparmor-utils'       => '2.5.1-0ubuntu0.10.04.4',
      'iptables'             => '1.4.4-2ubuntu2',
      'sysstat'              => '9.0.6-2',
      'rsync'                => '3.0.7-1ubuntu1.1',
      'openssh-server'       => '1:5.3p1-3ubuntu7',
      'traceroute'           => '2.0.13-2',
      'libncurses5-dev'      => '5.7+20090803-2ubuntu3',
      'quota'                => '3.17-6',
      'libaio1'              => '0.3.107-3ubuntu2',
      'gdb'                  => '7.1-1ubuntu2',
      'tripwire'             => '2.3.1.2.0-13',
      'libcap2-bin'          => '1:2.17-2ubuntu1.1',
      'libcap-dev'           => '1:2.17-2ubuntu1.1',
      'libbz2-dev'           => '1.0.5-4ubuntu0.2',
      'libyaml-dev'          => '0.1.3-1',
      'cmake'                => '2.8.0-5ubuntu1',
      'scsitools'            => '0.10-2.1ubuntu2',
      'mg'                   => '20090107-3',
      'htop'                 => '0.8.3-1ubuntu1',
      'module-assistant'     => '0.11.2ubuntu1',
      'debhelper'            => '7.4.15ubuntu1',
      'runit'                => '2.0.0-1ubuntu4',
      'sudo'                 => '1.7.2p1-1ubuntu5.6',
      'rsyslog'              => '4.2.0-2ubuntu8.1',
      'rsyslog-relp'         => '4.2.0-2ubuntu8.1',
    }.each do |pkg, version|
      describe package(pkg) do
        it { should be_installed.with_version(version) }
      end
    end

    describe file('/sbin/rescan-scsi-bus.sh') do
      it { should be_file }
      it { should be_executable }
    end
  end

  context 'installed by system_grub' do
    {
      'grub' => '0.97-29ubuntu60.10.04.2',
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
      'linux-image-virtual-lts-backport-oneiric'   => '3.0.0.32.20',
      'linux-headers-virtual-lts-backport-oneiric' => '3.0.0.32.20',
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
      it { should contain 'title Ubuntu 10.04.4 LTS (3.0.0-32-virtual)' }
      it { should contain '  root (hd0,0)' }
      it { should contain '  kernel /boot/vmlinuz-3.0.0-32-virtual ro root=UUID=' }
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
end
