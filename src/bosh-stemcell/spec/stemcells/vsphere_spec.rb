require 'spec_helper'

describe 'vSphere Stemcell', stemcell_image: true do
  it_behaves_like 'udf module is disabled'

  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      it { should contain('vsphere') }
    end
  end

  describe 'ssh authentication' do
    describe 'allows password authentication' do
      subject { file('/etc/ssh/sshd_config') }

      it { should_not contain /^PasswordAuthentication no$/ }
      it { should contain /^PasswordAuthentication yes$/ }
    end
  end
end

describe 'vSphere stemcell tarball', stemcell_tarball: true do
  context 'disables the floppy drive' do
    describe file("#{ENV['STEMCELL_WORKDIR']}/ovf/*.vmx") do
      its(:content) { should include('floppy0.present = "FALSE"') }
      its(:content) { should_not include('floppy0.clientDevice') }
      its(:content) { should_not include('floppy0.startConnected') }
    end
  end
end
