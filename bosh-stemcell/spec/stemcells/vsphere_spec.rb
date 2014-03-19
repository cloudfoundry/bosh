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
      it { should be_executable }
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

  context 'installed by system_open_vm_tools stage on Ubuntu' do
    before(:each) do
      pending 'only installed on Ubuntu' unless file('/var/vcap/bosh/etc/operating_system').contain('ubuntu', nil, nil)
    end

    %w(
      open-vm-dkms
      open-vm-tools
      vmware-tools-vmxnet3-modules-source
    ).each do |pkg|
      describe package(pkg) do
        it { should be_installed }
      end
    end

    describe file('/etc/rc2.d/S88open-vm-tools') do
      it { should be_linked_to('/etc/init.d/open-vm-tools') }
    end
  end
end
