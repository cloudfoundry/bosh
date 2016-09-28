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

    describe file('/etc/systemd/system/rsyslog.service.d/rsyslog_override.conf') do
      # this file is an rsyslog override which make s it wait for
      # the mountchecker service to start.
      it { should be_file }
      its(:content) { should match /^Requires=mountchecker.service/}
      its(:content) { should match /^After=mountchecker.service/ }
    end

    describe file('/etc/systemd/system/mountchecker.service') do
      # The mountchecker service waits for /var/log to be bind mounted
      # to /var/vcap/data/root_log, which is done in agent bootstrap.
      it { should be_file }
      its(:content) { should match /^ExecStart=\/usr\/bin\/bash -c 'until mountpoint -q \/var\/log; do sleep \.1; done'/}
    end
  end
end
