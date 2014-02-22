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
    %w(
      adduser
      apt
      apt-utils
      bzip2
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
      upstart
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
  end

  context 'installed by base_apt' do
    %w(
      upstart
      build-essential
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
      libyaml-dev
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
    %w(
      linux-image-virtual-lts-backport-oneiric
      linux-headers-virtual-lts-backport-oneiric
    ).each do |pkg|
      describe package(pkg) do
        it { should be_installed }
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
