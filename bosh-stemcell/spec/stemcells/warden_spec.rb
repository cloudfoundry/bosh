require 'spec_helper'

describe 'Warden Stemcell', stemcell_image: true do
  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      it { should contain('warden') }
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
