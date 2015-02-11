require 'spec_helper'

describe 'All OSes and Infrastructures', stemcell_image: true do
  describe 'sshd_config, set up by bosh_harden' do
    subject(:sshd_config) { file('/etc/ssh/sshd_config') }

    it 'is secure' do
      expect(sshd_config).to have_mode('600')
    end

    it 'shows a banner' do
      expect(sshd_config).to contain(%r{^Banner /etc/issue.net$/})
    end

    it 'disallows root login' do
      expect(sshd_config).to contain(/^PermitRootLogin no$/)
    end

    it 'disallows X11 forwarding' do
      expect(sshd_config).to contain(/^X11Forwarding no$/)
      expect(sshd_config).to_not contain(/^X11DisplayOffset/)
    end

    it 'sets MaxAuthTries to 3' do
      expect(sshd_config).to contain(/^MaxAuthTries 3$/)
    end
  end
end
