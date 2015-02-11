require 'spec_helper'

describe 'All OSes and Infrastructures', stemcell_image: true do
  context 'installed by bosh_harden' do
    subject(:sshd_config) { file('/etc/ssh/sshd_config') }

    it 'disallows root login' do
      expect(sshd_config).to contain(/^PermitRootLogin no$/)
      end

    it 'disallows CBC ciphers' do
      expect(sshd_config).to contain(/^Ciphers arcfour,arcfour128,arcfour256,aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com,chacha20-poly1305@openssh.com$/)
    end

    it 'disallows insecure HMACs' do
      expect(sshd_config).to contain(/^MACs hmac-sha1,hmac-sha2-256,hmac-sha2-512,hmac-ripemd160,hmac-ripemd160@openssh.com,umac-64@openssh.com,umac-128@openssh.com,hmac-sha1-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-ripemd160-etm@openssh.com,umac-128-etm@openssh.com$/)
    end
  end
end
