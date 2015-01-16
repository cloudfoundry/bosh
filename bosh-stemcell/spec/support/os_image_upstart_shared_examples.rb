shared_examples_for 'an upstart-based OS image' do

  context 'installed by rsyslog_config' do

    describe file('/etc/init/rsyslog.conf') do
      it { should contain('/usr/local/sbin/rsyslogd') }
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
