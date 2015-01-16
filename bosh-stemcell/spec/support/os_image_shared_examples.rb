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

    describe command("stat -c %a ~vcap") do
      it { should return_stdout("755") }
    end
  end

  context 'installed by rsyslog_config' do
    describe file('/etc/rsyslog.conf') do
      it { should be_file }
    end

    describe user('syslog') do
      it { should exist }
    end

    describe group('adm') do
      it { should exist }
    end
  end
end
