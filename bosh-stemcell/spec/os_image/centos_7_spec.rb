require 'spec_helper'

describe 'CentOS 7 OS image', os_image: true do
  it_behaves_like 'every OS image'
  it_behaves_like 'a CentOS or RHEL based OS image'
  it_behaves_like 'a systemd-based OS image'
  it_behaves_like 'a Linux kernel 3.x based OS image'
  it_behaves_like 'a Linux kernel module configured OS image'

  context 'installed by base_centos' do
    describe file('/etc/locale.conf') do
      it { should be_file }
      it { should contain 'en_US.UTF-8' }
    end

    %w(
      centos-release
      epel-release
    ).each do |pkg|
      describe package(pkg) do
        it { should be_installed }
      end
    end
  end

  context 'installed by base_centos_packages' do
    %w(
      bison
      bzip2-devel
      cloud-utils-growpart
      cmake
      cronie-anacron
      curl
      dhclient
      e2fsprogs
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
      NetworkManager
      net-tools
      nmap-ncat
      openssh-server
      openssl
      openssl-devel
      parted
      psmisc
      readline-devel
      rpm-build
      rpmdevtools
      rsync
      rsyslog
      rsyslog-relp
      rsyslog-gnutls
      rsyslog-mmjsonparse
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

    describe file('/usr/sbin/ifconfig') do
      it { should be_executable }
    end
  end

  context 'installed by system_grub' do
    describe package('grub2-tools') do
      it { should be_installed }
    end
  end

  context 'overriding control alt delete (stig: V-38668)' do
    describe file('/etc/systemd/system/ctrl-alt-del.target') do
      it { should be_file }
      it { should contain '# escaping ctrl alt del' }
    end
  end

  context 'official Centos gpg key is installed (stig: V-38476)' do
    describe command('rpm -qa gpg-pubkey* 2>/dev/null | xargs rpm -qi 2>/dev/null') do
      its (:stdout) { should include('CentOS 7 Official Signing Key') }
    end
  end

  context 'ensure sendmail is removed (stig: V-38671)' do
    describe command('rpm -q sendmail') do
      its (:stdout) { should include ('package sendmail is not installed')}
    end
  end

  context 'ensure cron is installed and enabled (stig: V-38605)' do
    describe package('cronie') do
      it('should be installed') { should be_installed }
    end

    describe file('/etc/systemd/system/default.target') do
      it { should be_file }
      its(:content) { should match /^Requires=multi-user\.target/ }
    end

    describe file('/etc/systemd/system/multi-user.target.wants/crond.service') do
      it { should be_file }
      its(:content) { should match /^ExecStart=\/usr\/sbin\/crond/ }
    end
  end

  # V-38498 and V-38495 are the package defaults and cannot be configured
  context 'ensure auditd is installed but not enabled (stig: V-38628) (stig: V-38631) (stig: V-38632) (stig: V-38498) (stig: V-38495)' do
    describe package('audit') do
      it { should be_installed }
    end

    describe file('/etc/systemd/system/default.target') do
      it { should be_file }
      its(:content) { should match /^Requires=multi-user\.target/ }
    end
  end

  context 'ensure xinetd is not installed nor enabled (stig: V-38582)' do
    describe package('xinetd') do
      it('should not be installed') { should_not be_installed }
    end

    describe file('/etc/systemd/system/default.target') do
      it { should be_file }
      its(:content) { should match /^Requires=multi-user\.target/ }
    end

    describe file('/etc/systemd/system/multi-user.target.wants/xinetd.service') do
      it { should_not be_file }
    end
  end

  context 'ensure ypbind is not installed nor enabled (stig: V-38604)' do
    describe package('ypbind') do
      it('should not be installed') { should_not be_installed }
    end

    describe file('/etc/systemd/system/default.target') do
      it { should be_file }
      its(:content) { should match /^Requires=multi-user\.target/ }
    end

    describe file('/etc/systemd/system/multi-user.target.wants/ypbind.service') do
      it { should_not be_file }
    end
  end

  context 'ensure ypserv is not installed (stig: V-38603)' do
    describe package('ypserv') do
      it('should not be installed') { should_not be_installed }
    end
  end

  context 'ensure audit package file have correct permissions (stig: V-38663)' do
    describe command('rpm -V audit | grep ^.M') do
      its (:stdout) { should be_empty }
    end
  end

  context 'ensure audit package file have correct owners (stig: V-38664)' do
    describe command("rpm -V audit | grep '^.....U'") do
      its (:stdout) { should be_empty }
    end
  end

  context 'ensure audit package file have correct groups (stig: V-38665)' do
    describe command("rpm -V audit | grep '^......G'") do
      its (:stdout) { should be_empty }
    end
  end

  context 'ensure audit package file have unmodified contents (stig: V-38637)' do
    # ignore auditd.conf, and audit.rules since we modify these files in
    # other stigs
    describe command("rpm -V audit | grep -v 'auditd.conf' | grep -v 'audit.rules' | grep -v 'syslog.conf' | grep '^..5'") do
      its (:stdout) { should be_empty }
    end
  end

  context 'PAM configuration' do
    describe file('/etc/pam.d/system-auth') do
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
  end

  context 'display the number of unsuccessful logon/access attempts since the last successful logon/access (stig: V-51875)' do
    describe file('/etc/pam.d/system-auth') do
      its(:content){ should match /session     required      pam_lastlog\.so showfailed/ }
    end
  end

  context 'gpgcheck must be enabled (stig: V-38483)' do
    describe file('/etc/yum.conf') do
      its(:content) { should match /^gpgcheck=1$/ }
    end
  end

  context 'installed by bosh_sysctl' do
    describe file('/etc/sysctl.d/60-bosh-sysctl.conf') do
      it { should be_file }

      it 'must limit the ability of processes to have simultaneous write and execute access to memory. (only centos) (stig: V-38597)' do
        should contain /^kernel.exec-shield=1$/
      end
    end
  end

  context 'ensure net-snmp is not installed (stig: V-38660) (stig: V-38653)' do
    describe package('net-snmp') do
      it { should_not be_installed }
    end
  end

  context 'ensure rpcbind is not enabled (CIS-6.7)' do
    describe file('/etc/init/rpcbind-boot.conf') do
      it { should_not be_file }
    end

    describe file('/etc/init/rpcbind.conf') do
      it { should_not be_file }
    end
  end

  describe 'ensure nfs is not enabled (CIS-6.7)' do
    describe command("ls /etc/rc*.d/ | grep S*nfs-kernel-server") do
      its (:stdout) { should be_empty }
    end
  end

  context 'restrict access to the su command CIS-9.5' do
    describe command('grep "^\s*auth\s*required\s*pam_wheel.so\s*use_uid" /etc/pam.d/su') do
      it { should return_exit_status(0)}
    end
    describe user('vcap') do
      it { should exist }
      it { should belong_to_group 'wheel' }
    end
  end

  describe 'logging and audit startup script' do
    describe file('/var/vcap/bosh/bin/bosh-start-logging-and-auditing') do
      it { should be_file }
      it { should be_executable }
      it { should contain('service auditd start') }
    end
  end
end
