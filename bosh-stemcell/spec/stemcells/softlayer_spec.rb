require 'spec_helper'

describe 'Softlayer Stemcell', stemcell_image: true do
  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      it { should contain('softlayer') }
    end
  end

  describe 'ssh authentication' do
    describe 'allows password authentication' do
      subject { file('/etc/ssh/sshd_config') }

      it { should_not contain /^PasswordAuthentication no$/ }
      it { should contain /^PasswordAuthentication yes$/ }
    end
  end

  describe 'ssh permit root login' do
    describe 'permit root login' do
      subject { file('/etc/ssh/sshd_config') }

      it { should_not contain /^PermitRootLogin no$/ }
      it { should contain /^PermitRootLogin yes$/ }
    end
  end
end
