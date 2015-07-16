shared_examples_for 'every OS image' do
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
      it { should contain '#includedir /etc/sudoers.d' }
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

  context 'installed by rsyslosyg_config' do
    before do
      system("sudo mount --bind /dev #{backend.chroot_dir}/dev")
    end

    after do
      system("sudo umount #{backend.chroot_dir}/dev")
    end

    describe file('/etc/rsyslog.conf') do
      it { should be_file }
      it { should contain '\$ModLoad omrelp' }
    end

    describe user('syslog') do
      it { should exist }
      it { should belong_to_group 'vcap' }
    end

    describe group('adm') do
      it { should exist }
    end

    describe command('rsyslogd -N 1') do
      it { should return_stdout /version 8/ }
      it { should return_exit_status(0) }
    end

    describe file('/etc/rsyslog.d/enable-kernel-logging.conf') do
      it { should be_file }
      it { should contain('ModLoad imklog') }
    end
  end

  describe 'the sshd_config, as set up by base_ssh' do
    subject(:sshd_config) { file('/etc/ssh/sshd_config') }

    it 'is secure' do
      expect(sshd_config).to be_mode('600')
    end

    it 'shows a banner' do
      expect(sshd_config).to contain(/^Banner/)
    end

    it 'disallows root login' do
      expect(sshd_config).to contain(/^PermitRootLogin no$/)
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

    it 'sets Banner to /etc/issue (stig: V-38615)' do
      expect(sshd_config).to contain(/^Banner \/etc\/issue$/)
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

  context 'anacron is configured' do
    describe file('/etc/anacrontab') do
      it { should be_file }
      it { should contain /^RANDOM_DELAY=60$/ }
      it { should_not contain /^RANDOM_DELAY=[0-57-9][0-9]*$/ }
    end
  end

  context 'tftp is not installed (stig: V-38701)' do
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

  context 'rsh-server is not installed (stig: V-38598, V-38591, V-38594, V-38602)' do
    describe package('rsh-server') do
      it { should_not be_installed }
    end
  end
end
