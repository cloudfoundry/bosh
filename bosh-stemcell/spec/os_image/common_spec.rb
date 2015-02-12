require 'spec_helper'

describe 'On all OSes and Infrastructures', os_image: true do
  describe 'the sshd_config, as set up by base_ssh' do
    subject(:sshd_config) { file('/etc/ssh/sshd_config') }

    it 'is secure' do
      expect(sshd_config).to be_mode('600')
    end

    it 'shows a banner' do
      expect(sshd_config).to contain(/^Banner/)
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
