require 'spec_helper'

describe 'Warden Stemcell', stemcell_image: true do
  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      it { should contain('warden') }
    end
  end

  context 'installs recent version of unshare so it gets the -p flag' do
    context 'so we can run upstart in as PID 1 in the container' do
      describe file('/var/vcap/bosh/bin/unshare') do
        it { should be_file }
        it { should be_executable }
        it { should be_owned_by('root') }
        it { should be_grouped_into('root') }
      end
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
