require 'spec_helper'

describe 'CentOS OS image', os_image: true do
  it_behaves_like 'an OS image'

  describe package('apt') do
    it { should_not be_installed }
  end

  describe package('rpm') do
    it { should be_installed }
  end

  context 'installed by base_centos' do
    %w(
      centos-release
      epel-release
    ).each do |pkg|
      describe package(pkg) do
        it { should be_installed }
      end
    end

    describe file('/etc/sysconfig/network') do
      it { should be_file }
    end

    describe file('/etc/localtime') do
      it { should be_file }
      it { should contain 'UTC' }
    end

    describe file('/etc/sysconfig/i18n') do
      it { should be_file }
      it { should contain 'en_US.UTF-8' }
    end
  end

  context 'installed by base_centos_packages' do
    %w(
      bison
      bzip2-devel
      cmake
      curl
      dhclient
      flex
      gdb
      glibc-static
      iptables
      libcap-devel
      libuuid-devel
      libxml2
      libxml2-devel
      libxslt
      libxslt-devel
      lsof
      nc
      openssh-server
      openssl-devel
      psmisc
      quota
      readline-devel
      rpm-build
      rpmdevtools
      rsync
      runit
      strace
      sudo
      sysstat
      tcpdump
      traceroute
      unzip
      upstart
      wget
      zip
    ).each do |pkg|
      describe package(pkg) do
        it { should be_installed }
      end
    end
  end

  context 'installed by system_grub' do
    describe package('grub') do
      it { should be_installed }
    end
  end

  %w(e2fs_stage1_5 stage1 stage2).each do |grub_stage|
    describe file("/boot/grub/#{grub_stage}") do
      it { should be_file }
    end
  end

  context 'installed by system_kernel' do
    %w(
      kernel
      kernel-headers
    ).each do |pkg|
      describe package(pkg) do
        it { should be_installed }
      end
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
