require 'bosh/stemcell/arch'
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
    describe package('linux-generic-lts-xenial') do
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

  context 'The system must limit the ability of processes to have simultaneous write and execute access to memory. (stig: V-38597)' do
    # Ubuntu relies on the system's hardware NX capabilities, or emulates NX if the hardware does not support it.
    # Ubuntu has had this capability since v 11.04
    # https://wiki.ubuntu.com/Security/Features#nx
    it 'should run an os that emulates or uses things' do
      major_version = os[:release].split('.')[0].to_i
      expect(major_version).to be > 11
    end
  end


  describe 'base_apt' do
    describe file('/etc/apt/sources.list') do
      if Bosh::Stemcell::Arch.ppc64le?
        it { should contain 'deb http://ports.ubuntu.com/ubuntu-ports/ trusty main restricted' }
        it { should contain 'deb http://ports.ubuntu.com/ubuntu-ports/ trusty-updates main restricted' }
        it { should contain 'deb http://ports.ubuntu.com/ubuntu-ports/ trusty universe' }
        it { should contain 'deb http://ports.ubuntu.com/ubuntu-ports/ trusty-updates universe' }
        it { should contain 'deb http://ports.ubuntu.com/ubuntu-ports/ trusty multiverse' }
        it { should contain 'deb http://ports.ubuntu.com/ubuntu-ports/ trusty-updates multiverse' }

        it { should contain 'deb http://ports.ubuntu.com/ubuntu-ports/ trusty-security main restricted' }
        it { should contain 'deb http://ports.ubuntu.com/ubuntu-ports/ trusty-security universe' }
        it { should contain 'deb http://ports.ubuntu.com/ubuntu-ports/ trusty-security multiverse' }

      else
        it { should contain 'deb http://archive.ubuntu.com/ubuntu trusty main universe multiverse' }
        it { should contain 'deb http://archive.ubuntu.com/ubuntu trusty-updates main universe multiverse' }
        it { should contain 'deb http://security.ubuntu.com/ubuntu trusty-security main universe multiverse' }
      end
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
    # rsyslog-mmjsonparse is removed because of https://gist.github.com/allomov-altoros/cd579aa76f3049bee9c7
    %w(
      anacron
      apparmor-utils
      bind9-host
      bison
      cloud-guest-utils
      cmake
      curl
      debhelper
      dnsutils
      flex
      gdb
      htop
      iptables
      iputils-arping
      libaio1
      libbz2-dev
      libcap-dev
      libcap2-bin
      libcurl3
      libcurl4-openssl-dev
      libgcrypt11-dev
      libncurses5-dev
      libpam-cracklib
      libreadline6-dev
      libssl-dev
      libxml2
      libxml2-dev
      libxslt1-dev
      libxslt1.1
      lsof
      mg
      module-assistant
      nfs-common
      openssh-server
      psmisc
      quota
      rsync
      rsyslog
      rsyslog-gnutls
      rsyslog-mmjsonparse
      rsyslog-relp
      runit
      scsitools
      strace
      sudo
      sysstat
      tcpdump
      traceroute
      unzip
      uuid-dev
      wget
      zip
    ).reject{ |pkg| Bosh::Stemcell::Arch.ppc64le? and ( pkg == 'rsyslog-mmjsonparse' or pkg == 'rsyslog-gnutls' or pkg == 'rsyslog-relp') }.each do |pkg|
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
    if Bosh::Stemcell::Arch.ppc64le?
      %w(
        grub2
      ).each do |pkg|
        describe package(pkg) do
          it { should be_installed }
        end
      end
      %w(grub grubenv grub.chrp).each do |grub_file|
        describe file("/boot/grub/#{grub_file}") do
          it { should be_file }
        end
      end
    else
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

  context 'package signature verification (stig: V-38462) (stig: V-38483)' do
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

  context 'PAM configuration' do
    if Bosh::Stemcell::Arch.ppc64le?
      describe file('/lib/powerpc64le-linux-gnu/security/pam_cracklib.so') do
        it { should be_file }
      end
    else
      describe file('/lib/x86_64-linux-gnu/security/pam_cracklib.so') do
        it { should be_file }
      end
    end

    describe file('/etc/pam.d/common-password') do
      it 'must prohibit the reuse of passwords within twenty-four iterations (stig: V-38658)' do
        should contain /password.*pam_unix\.so.*remember=24/
      end

      it 'must prohibit new passwords shorter than 14 characters (stig: V-38475)' do
        should contain /password.*pam_unix\.so.*minlen=14/
      end

      it 'must use the cracklib library to set correct password requirements (CIS-9.2.1)' do
        should contain /password.*pam_cracklib\.so.*retry=3.*minlen=14.*dcredit=-1.*ucredit=-1.*ocredit=-1.*lcredit=-1/
      end
    end

    describe file('/etc/pam.d/common-account') do
      it 'must reset the tally of a user after successful login, esp. `sudo` (stig: V-38573)' do
        should contain(/account.*required.*pam_tally2\.so/)
      end
    end

    describe file('/etc/pam.d/common-auth') do
      it 'must restrict a user account after 5 failed login attempts (stig: V-38573)' do
        should contain(/auth.*pam_tally2\.so.*deny=5/)
      end
    end
  end

  # V-38498 and V-38495 are the package defaults and cannot be configured
  context 'ensure auditd is installed (stig: V-38498) (stig: V-38495)' do
    describe package('auditd') do
      it { should be_installed }
    end
  end

  context 'ensure auditd file permissions and ownership (stig: V-38663) (stig: V-38664) (stig: V-38665)' do
    [[644, '/usr/share/lintian/overrides/auditd'],
    [755, '/usr/bin/auvirt'],
    [755, '/usr/bin/ausyscall'],
    [755, '/usr/bin/aulastlog'],
    [755, '/usr/bin/aulast'],
    [750, '/var/log/audit'],
    [755, '/sbin/aureport'],
    [755, '/sbin/auditd'],
    [755, '/sbin/autrace'],
    [755, '/sbin/ausearch'],
    [755, '/sbin/augenrules'],
    [755, '/sbin/auditctl'],
    [755, '/sbin/audispd'],
    [750, '/etc/audisp'],
    [750, '/etc/audisp/plugins.d'],
    [640, '/etc/audisp/plugins.d/af_unix.conf'],
    [640, '/etc/audisp/plugins.d/syslog.conf'],
    [640, '/etc/audisp/audispd.conf'],
    [755, '/etc/init.d/auditd'],
    [750, '/etc/audit'],
    [750, '/etc/audit/rules.d'],
    [640, '/etc/audit/rules.d/audit.rules'],
    [640, '/etc/audit/audit.rules'],
    [640, '/etc/audit/auditd.conf'],
    [644, '/etc/default/auditd'],
    [644, '/lib/systemd/system/auditd.service']].each do |tuple|
      describe file(tuple[1]) do
        it ('should be owned by root') { should be_owned_by('root')}
        it ('should be owned by root group') { should be_grouped_into('root')}
        it ("should have mode #{tuple[0]}") { should be_mode(tuple[0])}
      end
    end
  end

  context 'ensure audit package file have unmodified contents (stig: V-38637)' do
    # ignore auditd.conf, auditd, and audit.rules since we modify these files in
    # other stigs
    describe command("dpkg -V audit | grep -v 'auditd.conf' | grep -v 'default/auditd' | grep -v 'audit.rules' | grep -v 'syslog.conf' | grep '^..5'") do
      its (:stdout) { should be_empty }
    end
  end

  context 'ensure sendmail is removed (stig: V-38671)' do
    describe command('dpkg -s sendmail') do
      its (:stdout) { should include ('dpkg-query: package \'sendmail\' is not installed and no information is available')}
    end
  end

  describe service('xinetd') do
    it('should be disabled (stig: V-38582)') { should_not be_enabled }
  end

  context 'ensure cron is installed and enabled (stig: V-38605)' do
    describe package('cron') do
      it('should be installed') { should be_installed }
    end

    describe service('cron') do
      it('should be enabled') { should be_enabled }
    end
  end

  context 'ensure ypbind is not running (stig: V-38604)' do
    describe package('nis') do
      it { should_not be_installed }
    end
    describe file('/var/run/ypbind.pid') do
      it { should_not be_file }
    end
  end

  context 'ensure ypserv is not installed (stig: V-38603)' do
    describe package('nis') do
      it { should_not be_installed }
    end
  end

  context 'ensure snmp is not installed (stig: V-38660) (stig: V-38653)' do
    describe package('snmp') do
      it { should_not be_installed }
    end
  end

  context 'display the number of unsuccessful logon/access attempts since the last successful logon/access (stig: V-51875)' do
    describe file('/etc/pam.d/common-password') do
      its(:content){ should match /session     required      pam_lastlog\.so showfailed/ }
    end
  end

  context 'ensure whoopsie and apport are not installed (CIS-4.1)' do
    describe package('apport') do
      it { should_not be_installed }
    end
    describe package('whoopsie') do
      it { should_not be_installed }
    end
  end

  context 'restrict access to the su command CIS-9.5' do
    describe command('grep "^\s*auth\s*required\s*pam_wheel.so\s*use_uid" /etc/pam.d/su') do
      it { should return_exit_status(0)}
    end
    describe user('vcap') do
      it { should exist }
      it { should belong_to_group 'sudo' }
    end
  end

  describe 'logging and audit startup script' do
    describe file('/var/vcap/bosh/bin/bosh-start-logging-and-auditing') do
      it { should be_file }
      it { should be_executable }
      it { should contain('service auditd start') }
    end
  end

  describe 'allowed user accounts' do
    describe file('/etc/passwd') do
      its(:content) { should eql(<<HERE) }
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
games:x:5:60:games:/usr/games:/usr/sbin/nologin
man:x:6:12:man:/var/cache/man:/usr/sbin/nologin
lp:x:7:7:lp:/var/spool/lpd:/usr/sbin/nologin
mail:x:8:8:mail:/var/mail:/usr/sbin/nologin
news:x:9:9:news:/var/spool/news:/usr/sbin/nologin
uucp:x:10:10:uucp:/var/spool/uucp:/usr/sbin/nologin
proxy:x:13:13:proxy:/bin:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
backup:x:34:34:backup:/var/backups:/usr/sbin/nologin
list:x:38:38:Mailing List Manager:/var/list:/usr/sbin/nologin
irc:x:39:39:ircd:/var/run/ircd:/usr/sbin/nologin
gnats:x:41:41:Gnats Bug-Reporting System (admin):/var/lib/gnats:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
libuuid:x:100:101::/var/lib/libuuid:/usr/sbin/nologin
syslog:x:101:104::/home/syslog:/bin/false
sshd:x:102:65534::/var/run/sshd:/usr/sbin/nologin
statd:x:103:65534::/var/lib/nfs:/bin/false
vcap:x:1000:1000:BOSH System User:/home/vcap:/bin/bash
HERE
    end

    describe file('/etc/shadow') do
      shadow_match = Regexp.new <<'END_SHADOW', [Regexp::MULTILINE]
\Aroot:(.+):(\d{5}):0:99999:7:::
daemon:\*:(\d{5}):0:99999:7:::
bin:\*:(\d{5}):0:99999:7:::
sys:\*:(\d{5}):0:99999:7:::
sync:\*:(\d{5}):0:99999:7:::
games:\*:(\d{5}):0:99999:7:::
man:\*:(\d{5}):0:99999:7:::
lp:\*:(\d{5}):0:99999:7:::
mail:\*:(\d{5}):0:99999:7:::
news:\*:(\d{5}):0:99999:7:::
uucp:\*:(\d{5}):0:99999:7:::
proxy:\*:(\d{5}):0:99999:7:::
www-data:\*:(\d{5}):0:99999:7:::
backup:\*:(\d{5}):0:99999:7:::
list:\*:(\d{5}):0:99999:7:::
irc:\*:(\d{5}):0:99999:7:::
gnats:\*:(\d{5}):0:99999:7:::
nobody:\*:(\d{5}):0:99999:7:::
libuuid:!:(\d{5}):0:99999:7:::
syslog:\*:(\d{5}):0:99999:7:::
sshd:\*:(\d{5}):0:99999:7:::
statd:\*:(\d{5}):0:99999:7:::
vcap:(.+):(\d{5}):1:99999:7:::\Z
END_SHADOW

      its(:content) { should match(shadow_match) }
    end

    describe file('/etc/group') do
      its(:content) { should eql(<<HERE) }
root:x:0:
daemon:x:1:
bin:x:2:
sys:x:3:
adm:x:4:vcap
tty:x:5:
disk:x:6:
lp:x:7:
mail:x:8:
news:x:9:
uucp:x:10:
man:x:12:
proxy:x:13:
kmem:x:15:
dialout:x:20:vcap
fax:x:21:
voice:x:22:
cdrom:x:24:vcap
floppy:x:25:vcap
tape:x:26:
sudo:x:27:vcap
audio:x:29:vcap
dip:x:30:vcap
www-data:x:33:
backup:x:34:
operator:x:37:
list:x:38:
irc:x:39:
src:x:40:
gnats:x:41:
shadow:x:42:
utmp:x:43:
video:x:44:vcap
sasl:x:45:
plugdev:x:46:vcap
staff:x:50:
games:x:60:
users:x:100:
nogroup:x:65534:
libuuid:x:101:
netdev:x:102:
crontab:x:103:
syslog:x:104:
ssh:x:105:
admin:x:999:vcap
vcap:x:1000:syslog
bosh_sshers:x:1001:vcap
bosh_sudoers:x:1002:
HERE
    end

    describe file('/etc/gshadow') do
      its(:content) { should eql(<<HERE) }
root:*::
daemon:*::
bin:*::
sys:*::
adm:*::vcap
tty:*::
disk:*::
lp:*::
mail:*::
news:*::
uucp:*::
man:*::
proxy:*::
kmem:*::
dialout:*::vcap
fax:*::
voice:*::
cdrom:*::vcap
floppy:*::vcap
tape:*::
sudo:*::vcap
audio:*::vcap
dip:*::vcap
www-data:*::
backup:*::
operator:*::
list:*::
irc:*::
src:*::
gnats:*::
shadow:*::
utmp:*::
video:*::vcap
sasl:*::
plugdev:*::vcap
staff:*::
games:*::
users:*::
nogroup:*::
libuuid:!::
netdev:!::
crontab:!::
syslog:!::
ssh:!::
admin:!::vcap
vcap:!::syslog
bosh_sshers:!::vcap
bosh_sudoers:!::
HERE
    end
  end
end
