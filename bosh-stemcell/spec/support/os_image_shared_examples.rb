shared_examples_for 'every OS image' do
  let(:sshd_config) { file('/etc/ssh/sshd_config') }

  context 'installed by base_<os>' do
    describe command('dig -v') do # required by agent
      it { should return_exit_status(0) }
    end

    describe command('which crontab') do
      it { should return_exit_status(0) }
    end
  end

  context 'installed by bosh_sudoers' do
    describe file('/etc/sudoers') do
      it { should be_file }
      it { should contain '%bosh_sudoers ALL=(ALL) NOPASSWD: ALL' }
      it { should contain '#includedir /etc/sudoers.d' }
    end
  end

  context 'The sudo command must require authentication (stig: V-58901)' do
    describe command("egrep -sh 'NOPASSWD|!authenticate' /etc/sudoers /etc/sudoers.d/* | egrep -v '^#|%bosh_sudoers\s' --") do
      its (:stdout) { should eq('') }
    end
  end

  context 'installed by bosh_users' do
    describe command("grep -q 'export PATH=/var/vcap/bosh/bin:$PATH\n' /root/.bashrc") do
      it { should return_exit_status(0) }
    end

    describe command("grep -q 'export PATH=/var/vcap/bosh/bin:$PATH\n' /home/vcap/.bashrc") do
      it { should return_exit_status(0) }
    end

    describe command("grep -q .bashrc /root/.profile") do
      it { should return_exit_status(0) }
    end

    describe command("stat -c %a ~vcap") do
      it { should return_stdout("755") }
    end
  end

  describe cron do
    describe 'keeping the system clock up to date (stig: V-38620 V-38621)' do
      it { should have_entry '0,15,30,45 * * * * /var/vcap/bosh/bin/ntpdate' }
    end
  end

  describe '/etc/securetty' do
    it 'disallows virtual console access (stig: V-38492)' do
      expect(`grep '^vc/[0-9]+' #{backend.chroot_dir}/etc/securetty`).to be_empty
    end
  end

  # The STIG says to have the log files owned and grouped by 'root'. However, this would mean that
  # rsyslog would not be able to dropping privileges to another user. Because of this we've decided
  # it should run as the limited scope user 'syslog' which still prevents 'vcap' from reading the
  # logs (which is the original intention of the STIG).
  context 'all rsyslog-generated log files must be owned by syslog. (stig: V-38519 V-38518 V-38623)' do
    it 'secures rsyslog.conf-referenced files correctly' do
      rsyslog_log_file_list = [
        # get all logfile directives
        "grep --no-filename --recursive '/var/log/' #{backend.chroot_dir}/etc/rsyslog*",
        # filter commented directives
        "grep -v '^#'",
        # remove leading characters
        "sed 's%^[ \t]*%%' | awk '{ print $2 }' | tr -d '-'",
        # unique tests
        'sort | uniq',
      ].join('|')

      `#{rsyslog_log_file_list}`.split("\n").each do |logfile|
        f = file(logfile)

        expect(f).to be_owned_by('syslog') # stig: V-38518
        expect(f).to be_grouped_into('syslog') # stig: V-38519
        expect(f).to be_mode(600) # stig: V-38623

        expect(f).to_not be_readable.by_user('vcap')
        expect(f).to_not be_readable.by('vcap')
      end
    end
  end

  context 'installed by rsyslog_config' do
    before do
      system("sudo mount --bind /dev #{backend.chroot_dir}/dev")
    end

    after do
      system("sudo umount #{backend.chroot_dir}/dev")
    end

    describe file('/etc/rsyslog.conf') do
      it { should be_file }
      it { should contain '\$ModLoad omrelp' }
      it { should contain '\$FileGroup syslog' } # stig: V-38519
      it { should contain '\$FileUser syslog' } # stig: V-38518
      it { should contain '\$FileCreateMode 0600' } # stig: V-38623
    end

    describe user('syslog') do
      it { should exist }
      it { should belong_to_group 'vcap' }
    end

    describe group('adm') do
      it { should exist }
    end

    describe group('bosh_sudoers') do
      it { should exist }
    end

    describe command('rsyslogd -N 1'), exclude_on_ppc64le: true do
      it { should return_stdout /version 8/ }
      it { should return_exit_status(0) }
    end

    describe file('/etc/rsyslog.d/enable-kernel-logging.conf') do
      it { should be_file }
      it { should contain('ModLoad imklog') }
    end
  end

  context 'configured by base_ssh' do
    it 'is secure' do
      expect(sshd_config).to be_mode('600')
    end

    it 'disallows root login (stig: V-38613)' do
      expect(sshd_config).to contain(/^PermitRootLogin no$/)
    end

    it 'allows PrintLastLog (stig: V-38484)' do
      expect(sshd_config).to contain(/^PrintLastLog yes$/)
    end

    it 'disallows X11 forwarding' do
      expect(sshd_config).to contain(/^X11Forwarding no$/)
      expect(sshd_config).to_not contain(/^X11DisplayOffset/)
    end

    it 'sets MaxAuthTries to 3' do
      expect(sshd_config).to contain(/^MaxAuthTries 3$/)
    end

    it 'sets PermitEmptyPasswords to no (stig: V-38614)' do
      expect(sshd_config).to contain(/^PermitEmptyPasswords no$/)
    end

    it 'sets HostbasedAuthentication to no (stig: V-38612)' do
      expect(sshd_config).to contain(/^HostbasedAuthentication no$/)
    end

    it 'sets Banner to /etc/issue.net (stig: V-38615 V-38593)' do
      expect(sshd_config).to contain(/^Banner \/etc\/issue.net$/)

      banner = file('/etc/issue.net')

      # multiline message
      expect(banner).to contain('Unauthorized use is strictly prohibited. All access and activity')
      expect(banner).to contain('is subject to logging and monitoring.')
    end

    it 'sets IgnoreRhosts to yes (stig: V-38611)' do
      expect(sshd_config).to contain(/^IgnoreRhosts yes$/)
    end

    it 'sets ClientAliveInterval to 900 seconds (stig: V-38608)' do
      expect(sshd_config).to contain(/^ClientAliveInterval 900$/)
    end

    it 'sets PermitUserEnvironment to no (stig: V-38616)' do
      expect(sshd_config).to contain(/^PermitUserEnvironment no$/)
    end

    it 'sets ClientAliveCountMax to 0 (stig: V-38610)' do
      expect(sshd_config).to contain(/^ClientAliveCountMax 0$/)
    end

    it 'sets Protocol to 2 (stig: V-38607)' do
      expect(sshd_config).to contain(/^Protocol 2$/)
    end
  end

  describe 'PAM configuration' do
    context 'blank password logins are disabled (stig: V-38497)' do
      describe command('grep -R nullok /etc/pam.d') do
        it { should return_exit_status(1) }
        its (:stdout) { should eq('') }
      end
    end

    context 'a stronger hashing algorithm should be used (stig: V-38574)' do
      describe command('egrep -h -r "^password" /etc/pam.d | grep pam_unix.so | grep -v sha512') do
        it { should return_exit_status(1) }
        its (:stdout) { should eq('') }
      end
    end
  end

  context 'anacron is configured' do
    describe file('/etc/anacrontab') do
      it { should be_file }
      it { should contain /^RANDOM_DELAY=60$/ }
      it { should_not contain /^RANDOM_DELAY=[0-57-9][0-9]*$/ }
    end
  end

  context 'tftp is not installed (stig: V-38701, V-38609, V-38606)' do
    it "shouldn't be installed" do
      expect(package('tftp')).to_not be_installed
      expect(package('tftpd')).to_not be_installed
      expect(package('tftp-server')).to_not be_installed
      expect(package('atftp')).to_not be_installed
      expect(package('atftpd')).to_not be_installed
      expect(package('libnet-tftp-ruby')).to_not be_installed
      expect(package('python-tftpy')).to_not be_installed
      expect(package('tftp-hpa')).to_not be_installed
    end
  end

  context 'vsftpd is not installed (stig: V-38599)' do
    it "shouldn't be installed" do
      expect(package('vsftpd')).to_not be_installed
      expect(package('ftpd')).to_not be_installed
    end
  end

  context 'telnet-server is not installed (stig: V-38587, V-38589)' do
    it "shouldn't be installed" do
      expect(package('telnet-server')).to_not be_installed
      expect(package('telnetd')).to_not be_installed
      expect(package('telnetd-ssl')).to_not be_installed
      expect(package('telnet-server-krb5')).to_not be_installed
      expect(package('inetutils-telnetd')).to_not be_installed
      expect(package('mactelnet-server')).to_not be_installed
    end
  end

  context 'gconf2 is not installed (stig: V-43150) (stig: V-38638) (stig: V-38629) (stig: V-38630)' do
    describe package('gconf2') do
      it { should_not be_installed }
    end
  end

  context 'rsh-server is not installed (stig: V-38598, V-38591, V-38594, V-38602)' do
    describe package('rsh-server') do
      it { should_not be_installed }
    end
  end

  context '/etc/passwd file' do
    describe file('/etc/passwd') do
      it('should be owned by root user (stig: V-38450)') { should be_owned_by('root') }
      it('should be group-owned by root group (stig: V-38451)') { should be_grouped_into('root') }
      it('should have mode 0644 (stig: V-38457)') { should be_mode('644') }
    end

    context 'should not contain password hash (stig: V-38499)' do
      describe command('grep -v "^#" /etc/passwd | awk -F: \'($2 != "x") {print}\'') do
        its (:stdout) { should eq('') }
      end
    end
  end

  context '/etc/group file' do
    describe file('/etc/group') do
      it('should be owned by root user (stig: V-38458)') { should be_owned_by('root') }
      it('should be owned by root group (stig: V-38459)') { should be_grouped_into('root') }
      it('should have mode 0644 (stig: V-38461)') { should be_mode('644') }
    end
  end

  context '/etc/gshadow file' do
    describe file('/etc/gshadow') do
      it('should be owned by root user (stig: V-38443)') { should be_owned_by('root') }
      it('should be owned by root group (stig: V-38448)') { should be_grouped_into('root') }
      it('should have mode 0 (stig: V-38449)') { should be_mode('0') }
    end
  end

  context 'find world-writable files (stig: V-38643)' do
    describe command('find \/ -xdev -type f -perm -002') do
      its (:stdout) { should eq('') }
    end
  end

  describe file('/etc/login.defs') do
    it('should not allow users to cycle passwords quickly (stig: V-38477)') do
      should contain /^PASS_MIN_DAYS[[:space:]]\+1/
    end

    it('should use an approved hashing algorithm to save the password (stig: V-38576)') do
      should contain /^ENCRYPT_METHOD[[:space:]]\+SHA512/
    end
  end

  # NOTE: These shared examples are executed in the OS image building spec,
  # suites and the Stemcell building spec suites. In the OS image suites
  # nothing will be excluded, which is the desired behavior... we want all OS
  # images to perform theses stages. For the Stemcell suites the exlude flags
  # here apply.
  describe 'exceptions' do
    context 'unless: vcloud / vsphere / warden / softlayer', {
      exclude_on_vsphere: true,
      exclude_on_vcloud: true,
      exclude_on_warden: true,
      exclude_on_softlayer: true,
    } do
      it 'disallows password authentication' do
        expect(sshd_config).to contain(/^PasswordAuthentication no$/)
      end
    end

    context 'unless: softlayer', {
        exclude_on_softlayer: true,
    } do
      it 'disallows root login (stig: V-38613)' do
        expect(sshd_config).to contain(/^PermitRootLogin no$/)
      end
    end
  end

  describe package('xinetd') do
    it('should not be installed (stig: V-38582)') { should_not be_installed }
  end

  context 'The root account must be the only account having a UID of 0 (stig: V-38500)' do
    describe command("awk -F: '($3 == 0) {print}' /etc/passwd") do
      its (:stdout) { should eq("root:x:0:0:root:/root:/bin/bash\n") }
    end
  end

  describe file('/etc/shadow') do
    it('should be owned by root user (stig: V-38502)') { should be_owned_by('root') }
    it('should be owned by root group (stig: V-38503)') { should be_grouped_into('root') }
    it('should have mode 0 (stig: V-38504)') { should be_mode('0') }

    context 'contains no system users with passwords (stig: V-38496)' do
      describe command("awk -F: '$1 !~ /^root$/ && $1 !~ /^vcap$/ && $2 !~ /^[!*]/ {print $1 \":\" $2}' /etc/shadow") do
        it { should return_exit_status(0) }
        its (:stdout) { should eq('') }
      end
    end

    context 'contains no users with that can update their password frequently (stig: V-38477)' do
      describe command("awk -F: '$1 !~ /^root$/ && $2 !~ /^[!*]/ && $4 != \"1\" {print $1 \":\" $4}' /etc/shadow") do
        it { should return_exit_status(0) }
        its (:stdout) { should eq('') }
      end
    end

    context 'contains no users with that can update their password frequently (stig: V-38477)' do
      describe command("awk -F: '$1 !~ /^root$/ && $2 !~ /^[!*]/ && $4 != \"1\" {print $1 \":\" $4}' /etc/shadow") do
        it { should return_exit_status(0) }
        its (:stdout) { should eq('') }
      end
    end
  end

  describe 'IP forwarding for IPv4 must not be enabled (stig: V-38511)' do
    context file('/etc/sysctl.d/60-bosh-sysctl.conf') do
      its (:content) { should match /^net\.ipv4\.ip_forward=0$/ }
    end
  end

  describe 'address space layout randomization (ASLR)  should be enabled  (stig: V-38596)' do
    context file('/etc/sysctl.d/60-bosh-sysctl.conf') do
      its (:content) { should match /^kernel\.randomize_va_space=2$/ }
    end
  end

  describe 'syncookies should be enabled (stig: V-38539)' do
    context file('/etc/sysctl.d/60-bosh-sysctl.conf') do
      its (:content) { should match /^net\.ipv4\.tcp_syncookies=1$/ }
    end
  end

  describe 'auditd configuration' do
    describe file('/var/log/audit') do
      it { should be_directory }

      describe "Audit log directories must have mode 0755 or less permissive (750 by default) (stig: V-38493)" do
        it { should be_mode 750 }
      end
    end

    describe file('/etc/audit/auditd.conf') do
      describe 'logging disk errors to syslog (stig: V-38464)' do
        its (:content) { should match /^disk_error_action = SYSLOG$/ }
      end

      describe 'logging disks being low on space to syslog (stig: V-54381) (stig: V-38470)' do
        its (:content) { should match /^admin_space_left_action = SYSLOG$/ }
        its (:content) { should match /^space_left_action = SYSLOG$/ }
      end

      describe 'logging disks being full to syslog (stig: V-38468)' do
        its (:content) { should match /^disk_full_action = SYSLOG$/ }
      end

      describe 'keeping the log files under a certain size (stig: V-38633)' do
        its (:content) { should match /^max_log_file = 6$/ }
      end

      describe 'rotating the logs so the disk does not run out of space (stig: V-38634)' do
        its (:content) { should match /^max_log_file_action = ROTATE$/ }
      end

      describe 'keeping the logs around for a sensible retention period (stig: V-38636)' do
        its (:content) { should match /^num_logs = 5$/ }
      end

      describe 'audit log files must be group owned by root (stig: V-38445)' do
        its (:content) { should match /^log_group = root$/ }
      end

      describe 'audit log files triggers action when storage capacity is less than 75mb (stig: V-38678)' do
        its (:content) { should match /^space_left = 75$/ }
      end

      describe 'audit log files triggers action when storage capacity is less than 50mb (this must be less than space_left) (stig: V-38678)' do
        its (:content) { should match /^admin_space_left = 50$/ }
      end
    end

    describe file('/etc/audisp/plugins.d/syslog.conf') do
      describe 'auditd logs to syslog' do
        its (:content) { should match /^active = yes$/ }
      end
    end
  end

  describe 'loading and unloading of dynamic kernel modules must be audited (stig: V-38580)' do
    describe file('/etc/audit/rules.d/audit.rules') do
      its(:content) { should match /^-w \/sbin\/insmod -p x -k modules$/ }
      its(:content) { should match /^-w \/sbin\/rmmod -p x -k modules$/ }
      its(:content) { should match /^-w \/sbin\/modprobe -p x -k modules$/ }
      its(:content) { should match /^-w \/bin\/kmod -p x -k modules$/ }
      its(:content) { should match /-a always,exit -F arch=b64 -S finit_module -S init_module -S delete_module -k modules/ }
    end
  end

  context 'postfix is not installed (stig: V-38622) (stig: V-38446)' do
    it "shouldn't be installed" do
      expect(package('postfix')).to_not be_installed
    end
  end
end
