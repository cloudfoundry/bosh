require 'spec_helper'

describe 'Warden Stemcell', stemcell_image: true do
  it_behaves_like 'udf module is disabled'

  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      it { should contain('warden') }
    end
  end

  context 'rsyslog runit configuration' do
    describe file('/etc/sv/rsyslog/run') do
      its(:content) { should include('exec rsyslogd -n') }
      it { should be_executable }
    end

    describe file('/etc/service/rsyslog') do
      it { should be_linked_to '/etc/sv/rsyslog' }
    end
  end

  context 'ssh runit configuration' do
    describe file('/etc/sv/ssh/run') do
      its(:content) { should include('exec /usr/sbin/sshd -D') }
      it { should be_executable }
    end

    describe file('/etc/service/ssh') do
      it { should be_linked_to '/etc/sv/ssh' }
    end
  end

  context 'cron runit configuration' do
    describe file('/etc/sv/cron/run') do
      its(:content) { should include('exec cron -f') }
      it { should be_executable }
    end

    describe file('/etc/service/cron') do
      it { should be_linked_to '/etc/sv/cron' }
    end
  end

  context 'installed by bosh_disable_password_authentication' do
    describe 'disallows password authentication' do
      subject { file('/etc/ssh/sshd_config') }

      it { should_not contain /^PasswordAuthentication no$/ }
      it { should contain /^PasswordAuthentication yes$/ }
    end
  end
end
