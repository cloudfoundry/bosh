shared_examples_for 'a systemd-based OS image' do

  context 'installed by rsyslog_config' do
    # systemd startup may not be needed: see https://www.pivotaltracker.com/story/show/90100234
  end

  context 'systemd services' do
    describe command('systemctl is-enabled NetworkManager') do
      it { should return_stdout /enabled/ }
    end

    describe command('systemctl is-enabled runit') do
      it { should return_stdout /enabled/ }
    end

    describe command('systemctl is-enabled rsyslog') do
      it { should return_stdout /enabled/ }
    end
  end

  context 'limit password reuse' do
    describe file('/etc/pam.d/system-auth') do
      it 'must prohibit the reuse of passwords within twenty-four iterations (stig: V-38658)' do
        should contain /password.*pam_unix\.so.*remember=24/
      end
    end
  end
end
