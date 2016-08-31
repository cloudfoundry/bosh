shared_examples_for 'an upstart-based OS image' do

  context 'installed by rsyslog_config' do

    RSYSLOG_EXECUTABLE = '/usr/sbin/rsyslogd'

    # verify that the path used in the upstart config points to an actual executable
    describe file(RSYSLOG_EXECUTABLE) do
      it { should be_file }
      it { should be_executable }
    end
  end

  context 'X Windows must not be enabled unless required (stig: V-38674)' do
    describe package('xserver-xorg') do
      it { should_not be_installed }
    end
  end
end
