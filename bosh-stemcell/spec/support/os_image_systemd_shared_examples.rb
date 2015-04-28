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
end
