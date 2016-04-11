require 'spec_helper'

describe 'Google Stemcell', stemcell_image: true do
  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      it { should contain('google') }
    end
  end

  context 'installed by bosh_disable_password_authentication' do
    describe 'disallows password authentication' do
      subject { file('/etc/ssh/sshd_config') }

      it { should contain /^PasswordAuthentication no$/ }
    end
  end

  context 'installed by system_google_packages' do
    case ENV['OS_NAME']
      when 'ubuntu'
        describe file('/etc/init/google-accounts-manager-service.conf') do
          it { should be_file }
          it { should be_executable }
        end

        describe file('/etc/init/google-accounts-manager-task.conf') do
          it { should be_file }
          it { should be_executable }
        end

        describe file('/etc/init/google-clock-sync-manager.conf') do
          it { should be_file }
          it { should be_executable }
        end
      when 'centos', 'rhel'
        describe file('/usr/lib/systemd/system/google-accounts-manager.service') do
          it { should be_file }
        end

        describe file('/usr/lib/systemd/system/google-accounts-manager.service') do
          it { should be_file }
        end

        describe file('/usr/lib/systemd/system/google-clock-sync-manager.service') do
          it { should be_file }
        end
    end
  end
end
