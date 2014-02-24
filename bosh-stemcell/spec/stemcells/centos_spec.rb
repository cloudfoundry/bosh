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
  end

  context 'installed by base_yum' do
    %w(
      upstart
      openssl-devel
      lsof
      quota
      rsync
      strace
      iptables
      sysstat
      tcpdump
      dhclient
      zip
      traceroute
      gdb
      curl
      readline-devel
      flex
      openssh-server
      wget
      libxml2
      libxml2-devel
      libxslt
      libxslt-devel
      psmisc
      unzip
      bison
      libyaml
      libyaml-devel
      bzip2-devel
      libcap-devel
      cmake
      rpm-build
      rpmdevtools
      glibc-static
      runit
      sudo
      libuuid-devel
      nc
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
      it { should contain 'title CentOS release 6.5 (Final) ' }
      it { should contain '  root (hd0,0)' }
      it { should contain ' xen_blkfront.sda_is_xvda=1 ro root=UUID=' }
      it { should contain ' selinux=0' }
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
