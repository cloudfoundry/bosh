require 'spec_helper'

describe 'CentOS 6.x OS image', os_image: true do
  it_behaves_like 'every OS image'
  it_behaves_like 'an upstart-based OS image'

  context 'installed by rsyslog_build' do
    describe command('rsyslogd -v') do
      it { should return_stdout /7\.4\.6/ }
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

    %w(e2fs_stage1_5 stage1 stage2).each do |grub_stage|
      describe file("/boot/grub/#{grub_stage}") do
        it { should be_file }
      end
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
