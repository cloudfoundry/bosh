require 'spec_helper'

describe 'OpenStack Stemcell', stemcell_image: true do
  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      it { should contain('openstack') }
    end
  end

  context 'installed by package_qcow2_image stage' do
    describe 'converts to qcow2 0.10(x86) or 1.1(ppc64le) compat' do
      # environment is cleaned up inside rspec context
      stemcell_image = ENV['STEMCELL_IMAGE']

      subject do
        cmd = "qemu-img info #{File.join(File.dirname(stemcell_image), 'root.qcow2')}"
        `#{cmd}`
      end

      it {
        compat = Bosh::Stemcell::Arch.ppc64le? ? '1.1' : '0.10'
        should include("compat: #{compat}") 
      }
    end
  end

  context 'installed by bosh_disable_password_authentication' do
    describe 'disallows password authentication' do
      subject { file('/etc/ssh/sshd_config') }

      it { should contain /^PasswordAuthentication no$/ }
    end
  end
end
