require 'spec_helper'

describe 'Ubuntu 14.04 OS image', os_image: true do
  it_behaves_like 'every OS image'
  it_behaves_like 'an upstart-based OS image'
  it_behaves_like 'a Linux kernel 3.x based OS image'
  it_behaves_like 'a Linux kernel module configured OS image'

  describe package('apt') do
    it { should be_installed }
  end

  describe package('rpm') do
    it { should_not be_installed }
  end

  context 'installed by system_kernel' do
    describe package('linux-generic-lts-vivid') do
      it { should be_installed }
    end
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
      eject
      gnupg
      ifupdown
      initramfs-tools
      iproute2
      iputils-ping
      isc-dhcp-client
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
      parted
      passwd
      procps
      sudo
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
      it { should contain 'DISTRIB_RELEASE=14.04' }
      it { should contain 'DISTRIB_CODENAME=trusty' }
    end

    describe command('locale -a') do
      its(:stdout) { should include 'en_US.utf8' }
    end
  end

  describe 'base_apt' do
    describe file('/etc/apt/sources.list') do
      it { should contain 'deb http://archive.ubuntu.com/ubuntu trusty main universe multiverse' }
      it { should contain 'deb http://archive.ubuntu.com/ubuntu trusty-updates main universe multiverse' }
      it { should contain 'deb http://security.ubuntu.com/ubuntu trusty-security main universe multiverse' }
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
      anacron
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
      rsyslog
      rsyslog-relp
      rsyslog-gnutls
      rsyslog-mmjsonparse
      openssh-server
      traceroute
      libncurses5-dev
      quota
      libaio1
      gdb
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

  context 'installed by base_ssh' do
    subject(:sshd_config) { file('/etc/ssh/sshd_config') }

    it 'only allow 3DES and AES series ciphers (stig: V-38617)' do
      ciphers = %w(
        aes256-gcm@openssh.com
        aes128-gcm@openssh.com
        aes256-ctr
        aes192-ctr
        aes128-ctr
      ).join(',')
      expect(sshd_config).to contain(/^Ciphers #{ciphers}$/)
    end

    it 'allows only secure HMACs and the weaker SHA1 HMAC required by golang ssh lib' do
      macs = %w(
        hmac-sha2-512-etm@openssh.com
        hmac-sha2-256-etm@openssh.com
        hmac-ripemd160-etm@openssh.com
        umac-128-etm@openssh.com
        hmac-sha2-512
        hmac-sha2-256
        hmac-ripemd160
        hmac-sha1
      ).join(',')
      expect(sshd_config).to contain(/^MACs #{macs}$/)
    end
  end

  context 'installed by system_grub' do
    %w(
      grub
    ).each do |pkg|
      describe package(pkg) do
        it { should be_installed }
      end
    end

    %w(e2fs_stage1_5 stage1 stage2).each do |grub_stage|
      describe file("/boot/grub/#{grub_stage}") do
        it { should be_file }
      end
    end
  end

  context 'installed by bosh_user' do
    describe file('/etc/passwd') do
      it { should be_file }
      it { should contain '/home/vcap:/bin/bash' }
    end
  end

  context 'installed from source' do
    describe package('libyaml-dev') do
      it { should_not be_installed }
    end
  end

  context 'symlinked by vim_tiny' do
    describe file('/usr/bin/vim') do
      it { should be_linked_to '/usr/bin/vim.tiny' }
    end
  end

  context 'configured by cron_config' do
    describe file '/etc/cron.daily/man-db' do
      it { should_not be_file }
    end

    describe file '/etc/cron.weekly/man-db' do
      it { should_not be_file }
    end

    describe file '/etc/apt/apt.conf.d/02periodic' do
      it { should contain <<EOF }
APT::Periodic {
  Enable "0";
}
EOF
    end
  end

  context 'overriding control alt delete (stig: V-38668)' do
    describe file('/etc/init/control-alt-delete.override') do
      it { should be_file }
      it { should contain 'exec /usr/bin/logger -p security.info "Control-Alt-Delete pressed"' }
    end
  end

  context 'package signature verification (stig: V-38462)' do
    # verify default behavior was not changed
    describe command('grep -R AllowUnauthenticated /etc/apt/apt.conf.d/') do
      its (:stdout) { should eq('') }
    end
  end

  context 'official Ubuntu gpg key is installed (stig: V-38476)' do
    describe command('apt-key list') do
      its (:stdout) { should include('Ubuntu Archive Automatic Signing Key') }
    end
  end
end
