require 'spec_helper'

describe 'All OSes and Infrastructures', stemcell_image: true do
  context 'installed by bosh_harden' do
    describe 'disallow root login' do
      subject { file('/etc/ssh/sshd_config') }

      it { should contain /^PermitRootLogin no$/ }
    end
  end
end
