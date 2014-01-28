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
      it { should contain('KERNEL=="sr0", ACTION=="change", RUN+="/etc/udev/rules.d/ready_cdrom.sh"') }
    end

    describe file('/etc/udev/rules.d/ready_cdrom.sh') do
      it { should be_file }
      it { should contain(<<HERE) }
if [ -f /dev/bosh-cdrom ]
then
  rm -f /dev/bosh-cdrom
else
  touch /dev/bosh-cdrom
fi
HERE
    end
  end
end
