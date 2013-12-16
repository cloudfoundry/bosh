shared_examples_for 'a stemcell' do
  context 'installed by bosh_sudoers' do
    describe file('/etc/sudoers') do
      it { should be_file }
      it { should contain '#includedir /etc/sudoers.d' }
    end
  end

  # currently `should cotain` on a file does not properly escape $PATH
  context 'installed by bosh_users' do
    describe command("grep -q 'export PATH=/var/vcap/bosh/bin:\\$PATH\n' /root/.bashrc") do
      it { should return_exit_status(0) }
    end

    describe command("grep -q 'export PATH=/var/vcap/bosh/bin:\\$PATH\n' /home/vcap/.bashrc") do
      it { should return_exit_status(0) }
    end
  end

  context 'installed by base_<os>' do

    # required by go_agent
    describe command('dig -v') do
      it { should return_exit_status(0) }
    end
  end

  context 'installed by rsyslog' do

    describe file('/etc/rsyslog.conf') do
      it { should be_file }
    end

    describe file('/etc/init.d/rsyslog') do
      it { should be_file }
      it { should be_executable }
    end

    describe command('rsyslogd -v') do
      it { should return_stdout /7\.4\.7/ }
    end
  end
end
