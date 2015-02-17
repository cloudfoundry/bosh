require 'spec_helper'

describe 'RHEL OS image', os_image: true do
  it_behaves_like 'every OS image'
  it_behaves_like 'a systemd-based OS image'

  context 'installed by base_rhel' do
    %w(
      redhat-release-server
      epel-release
    ).each do |pkg|
      describe package(pkg) do
        it { should be_installed }
      end
    end

    describe file('/etc/locale.conf') do
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
      nmap-ncat
      openssh-server
      openssl-devel
      parted
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
      systemd
      tcpdump
      traceroute
      unzip
      wget
      zip
    ).each do |pkg|
      describe package(pkg) do
        it { should be_installed }
      end
    end
  end

  context 'installed by system_grub' do
    describe package('grub2-tools') do
      it { should be_installed }
    end
  end

  context 'rsyslog_build' do
    describe file('/etc/rsyslog_build.d/enable-kernel-logging.conf') do
      # Make sure imklog module is not loaded in rsyslog_build
      # to avoid CentOS stemcell pegging CPU on AWS
      it { should_not be_file } # (do not add $ in front of ModLoad because it will break the serverspec regex match)
    end
  end
end
