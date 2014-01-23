require 'spec_helper'

describe 'vSphere Stemcell' do
  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      it { should contain('vsphere') }
    end
  end

  context 'installed by image_vsphere_cdrom stage' do
    describe file('/etc/udev/rules.d/95-bosh-cdrom.rules') do
      it { should be_file }
      it { should contain('KERNEL=="sr0", SYMLINK+="bosh-cdrom"') }
    end
  end
end
