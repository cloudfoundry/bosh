require 'spec_helper'

describe 'All OSes and Infrastructures', stemcell_image: true do
  context 'installed by bosh_harden' do
    subject(:sshd_config) { file('/etc/ssh/sshd_config') }

    it 'disallows root login' do
      expect(sshd_config).to contain(/^PermitRootLogin no$/)
    end
  end
end
