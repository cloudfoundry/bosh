shared_examples_for 'a stemcell' do
  context 'installed by base_<os>' do
    describe command('dig -v') do # required by go_agent
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
  end

  context 'installed by rsyslog' do
    describe file('/etc/init/rsyslog.conf') do
      it { should contain('/usr/local/sbin/rsyslogd') }
    end

    describe file('/etc/rsyslog.conf') do
      it { should be_file }
    end

    describe user('syslog') do
      it { should exist }
    end

    describe group('adm') do
      it { should exist }
    end

    describe command('rsyslogd -v') do
      it { should return_stdout /7\.4\.6/ }
    end

    # Make sure that rsyslog starts with the machine
    describe file('/etc/init.d/rsyslog') do
      it { should be_file }
      it { should be_executable }
    end

    describe service('rsyslog') do
      it { should be_enabled.with_level(2) }
      it { should be_enabled.with_level(3) }
      it { should be_enabled.with_level(4) }
      it { should be_enabled.with_level(5) }
    end
  end
end
