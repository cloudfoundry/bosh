require 'spec_helper'

describe 'Ubuntu 10.04 OS image', os_image: true do
  it_behaves_like 'an OS image'

  describe package('apt') do
    it { should be_installed }
  end

  describe package('rpm') do
    it { should_not be_installed }
  end

  context 'installed by base_debootstrap' do
    %w(
      adduser
      apt
      apt-utils
      bzip2
      ca-certificates
      console-setup
      dash
      debconf
      dhcp3-client
      eject
      gnupg
      ifupdown
      initramfs-tools
      iproute
      iputils-ping
      kbd
      less
      locales
      lsb-release
      makedev
      mawk
      module-init-tools
      net-tools
      netbase
      netcat-openbsd
      ntpdate
      passwd
      procps
      python
      sudo
      tasksel
      tzdata
      ubuntu-keyring
      udev
      ureadahead
      vim-tiny
      whiptail
    ).each do |pkg|
      describe package(pkg) do
        it { should be_installed }
      end
    end

    describe file('/etc/lsb-release') do
      it { should be_file }
      it { should contain 'DISTRIB_RELEASE=10.04' }
      it { should contain 'DISTRIB_CODENAME=lucid' }
    end

    describe command('locale -a') do
      its(:stdout) { should include 'en_US.utf8' }
    end
  end

  describe 'base_apt' do
    describe file('/etc/apt/sources.list') do
      it { should contain 'deb http://archive.ubuntu.com/ubuntu lucid main universe multiverse' }
      it { should contain 'deb http://archive.ubuntu.com/ubuntu lucid-updates main universe multiverse' }
      it { should contain 'deb http://security.ubuntu.com/ubuntu lucid-security main universe multiverse' }
    end

    describe package('upstart') do
      it { should be_installed }
    end
  end

  context 'installed by base_ubuntu_build_essential' do
    describe package('build-essential') do
      it { should be_installed }
    end
  end

  context 'installed by base_ubuntu_packages' do
    %w(
      libssl-dev
      lsof
      strace
      bind9-host
      dnsutils
      tcpdump
      iputils-arping
      curl
      wget
      libcurl3
      libcurl4-openssl-dev
      bison
      libreadline6-dev
      libxml2
      libxml2-dev
      libxslt1.1
      libxslt1-dev
      zip
      unzip
      nfs-common
      flex
      psmisc
      apparmor-utils
      iptables
      sysstat
      rsync
      openssh-server
      traceroute
      libncurses5-dev
      quota
      libaio1
      gdb
      tripwire
      libcap2-bin
      libcap-dev
      libbz2-dev
      cmake
      scsitools
      mg
      htop
      module-assistant
      debhelper
      runit
      sudo
      uuid-dev
      libgcrypt11-dev
    ).each do |pkg|
      describe package(pkg) do
        it { should be_installed }
      end
    end

    describe file('/sbin/rescan-scsi-bus') do
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
    %w(
      linux-image-3.0.0-32-virtual
      linux-headers-3.0.0-32
      linux-headers-3.0.0-32-virtual
    ).each do |pkg|
      describe package(pkg) do
        it { should be_installed }
      end
    end
  end

  context 'installed by bosh_user' do
    describe file('/etc/passwd') do
      it { should be_file }
      it { should contain '/home/vcap:/bin/bash' }
    end
  end

  context 'installed by bosh_sysctl' do
    describe file('/etc/sysctl.d/60-bosh-sysctl.conf') do
      it { should be_file }
    end

    describe file('/etc/sysctl.d/60-bosh-sysctl-neigh-fix.conf') do
      it { should_not be_file }
    end
  end
end
