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
      'adduser' => '3.112ubuntu1',
      'apt' => '0.7.25.3ubuntu9.14',
      'apt-utils' => '0.7.25.3ubuntu9.14',
      'bzip2' => '1.0.5-4ubuntu0.2',
      'console-setup' => '1.34ubuntu15',
      'dash' => '0.5.5.1-3ubuntu2',
      'debconf' => '1.5.28ubuntu4',
      'dhcp3-client' => '3.1.3-2ubuntu3.5',
      'eject' => '2.1.5+deb1+cvs20081104-7',
      'gnupg' => '1.4.10-2ubuntu1.5',
      'ifupdown' => '0.6.8ubuntu29.2',
      'initramfs-tools' => '0.92bubuntu78',
      'iproute' => '20091226-1',
      'iputils-ping' => '3:20071127-2ubuntu1',
      'kbd' => '1.15-1ubuntu3',
      'less' => '436-1',
      'locales' => '2.11+git20100304-3',
      'lsb-release' => '4.0-0ubuntu8.1',
      'makedev' => '2.3.1-89ubuntu1',
      'mawk' => '1.3.3-15ubuntu2',
      'module-init-tools' => '3.11.1-2ubuntu1',
      'net-tools' => '1.60-23ubuntu2',
      'netbase' => '4.35ubuntu3',
      'netcat-openbsd' => '1.89-3ubuntu2',
      'ntpdate' => '1:4.2.4p8+dfsg-1ubuntu2.1',
      'passwd' => '1:4.1.4.2-1ubuntu2.2',
      'procps' => '1:3.2.8-1ubuntu4.3',
      'python' => '2.6.5-0ubuntu1.1',
      'sudo' => '1.7.2p1-1ubuntu5.6',
      'tasksel' => '2.73ubuntu26',
      'tzdata' => '2013g-0ubuntu0.10.04',
      'ubuntu-keyring' => '2010.11.09',
      'udev' => '151-12.3',
      'upstart' => '0.6.5-8',
      'ureadahead' => '0.100.0-4.1.3',
      'vim-tiny' => '2:7.2.330-1ubuntu3.1',
      'whiptail' => '0.52.10-5ubuntu1'
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
      'curl'                 => '7.19.7-1ubuntu1.5',
      'wget'                 => '1.12-1.1ubuntu2.1',
      'libcurl3'             => '7.19.7-1ubuntu1.5',
      'libcurl4-openssl-dev' => '7.19.7-1ubuntu1.5', # installed because of 'libcurl3-dev'
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
      'uuid-dev'             => '2.17.2-0ubuntu1.10.04.2',
      'libgcrypt11-dev'      => '1.4.4-5ubuntu2.2',
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
    describe file('/boot/grub/grub.conf') do
      it { should be_file }
      it { should contain 'default=0' }
      it { should contain 'timeout=1' }
      it { should contain 'title Ubuntu 10.04.4 LTS (3.0.0-32-virtual)' }
      it { should contain '  root (hd0,0)' }
      it { should contain '  kernel /boot/vmlinuz-3.0.0-32-virtual ro root=UUID=' }
      it { should contain ' selinux=0' }
      it { should contain '  initrd /boot/initrd.img-3.0.0-32-virtual' }
    end

    describe file('/boot/grub/menu.lst') do
      before { pending 'until aws/openstack stop clobbering the symlink with "update-grub"' }
      it { should be_linked_to('./grub.conf') }
    end
  end

  context 'installed by bosh_user' do
    describe file('/etc/passwd') do
      it { should be_file }
      it { should contain '/home/vcap:/bin/bash' }
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

  context 'installed by system-aws-network', exclude_on_vsphere: true do
    describe file('/etc/network/interfaces') do
      it { should be_file }
      it { should contain 'auto eth0' }
      it { should contain 'iface eth0 inet dhcp' }
    end
  end
end
