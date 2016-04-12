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
    let(:mode) { '644' }
    let(:owner) { 'root' }
    let(:group) { 'root' }
    case ENV['OS_NAME']
      when 'ubuntu'
        [
          '/etc/init/google-accounts-manager-service.conf',
          '/etc/init/google-accounts-manager-task.conf',
          '/etc/init/google-clock-sync-manager.conf'
        ].each do |conf_file|
          describe file(conf_file) do
            it { should be_file }
            it { should be_mode(mode) }
            it { should be_owned_by(owner) }
            it { should be_grouped_into(group) }
          end
        end
      when 'centos', 'rhel'
        [
          '/usr/lib/systemd/system/google-accounts-manager.service',
          '/usr/lib/systemd/system/google-accounts-manager.service',
          '/usr/lib/systemd/system/google-clock-sync-manager.service'
        ].each do |conf_file|
          describe file(conf_file) do
            it { should be_file }
            it { should be_mode(mode) }
            it { should be_owned_by(owner) }
            it { should be_grouped_into(group) }
          end
        end
    end
  end
end
