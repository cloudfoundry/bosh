require 'spec_helper'
require 'bosh/stemcell/infrastructure'

module Bosh::Stemcell
  describe Infrastructure do
    describe '.for' do
      it 'returns the correct infrastrcture' do
        expect(Infrastructure.for('openstack')).to be_an(Infrastructure::OpenStack)
        expect(Infrastructure.for('aws')).to be_an(Infrastructure::Aws)
        expect(Infrastructure.for('google')).to be_an(Infrastructure::Google)
        expect(Infrastructure.for('vsphere')).to be_a(Infrastructure::Vsphere)
        expect(Infrastructure.for('warden')).to be_a(Infrastructure::Warden)
        expect(Infrastructure.for('vcloud')).to be_a(Infrastructure::Vcloud)
        expect(Infrastructure.for('azure')).to be_a(Infrastructure::Azure)
        expect(Infrastructure.for('softlayer')).to be_a(Infrastructure::Softlayer)
        expect(Infrastructure.for('null')).to be_an(Infrastructure::NullInfrastructure)
      end

      it 'raises for unknown instructures' do
        expect {
          Infrastructure.for('BAD_INFRASTRUCTURE')
        }.to raise_error(ArgumentError, /invalid infrastructure: BAD_INFRASTRUCTURE/)
      end
    end
  end

  describe Infrastructure::Base do
    it 'requires a name to be specified' do
      expect {
        Infrastructure::Base.new
      }.to raise_error /key not found: :name/
    end

    it 'requires a hypervisor' do
      expect {
        Infrastructure::Base.new(name: 'foo', default_disk_size: 1024)
      }.to raise_error /key not found: :hypervisor/
    end

    it 'requires a default_disk_size' do
      expect {
        Infrastructure::Base.new(name: 'foo', hypervisor: 'xen')
      }.to raise_error /key not found: :default_disk_size/
    end

    it 'defaults to no additional cloud properties' do
      infrastructure = Infrastructure::Base.new(
        name: 'foo',
        hypervisor: 'xen',
        default_disk_size: 1024,
        disk_formats: []
      )
      expect(infrastructure.additional_cloud_properties).to eq({})
    end
  end

  describe Infrastructure::NullInfrastructure do
    it 'has the correct name' do
      expect(subject.name).to eq('null')
    end

    it 'has a null hypervisor' do
      expect(subject.hypervisor).to eq('null')
    end

    it 'has an impossible default disk size' do
      expect(subject.default_disk_size).to eq(-1)
    end

    it 'is comparable to other infrastructures' do
      expect(subject).to eq(Infrastructure.for('null'))

      expect(subject).to_not eq(Infrastructure.for('openstack'))
      expect(subject).to_not eq(Infrastructure.for('aws'))
      expect(subject).to_not eq(Infrastructure.for('vsphere'))
      expect(subject).to_not eq(Infrastructure.for('azure'))
      expect(subject).to_not eq(Infrastructure.for('softlayer'))
    end

    it 'defaults to no additional cloud properties' do
      infrastructure = Infrastructure::Base.new(
        name: 'foo',
        hypervisor: 'xen',
        default_disk_size: 1024,
        disk_formats: []
      )
      expect(infrastructure.additional_cloud_properties).to eq({})
    end
  end

  describe Infrastructure::Aws do
    its(:name)              { should eq('aws') }
    its(:hypervisor)        { should eq('xen') }
    its(:default_disk_size) { should eq(3072) }
    its(:disk_formats)      { should eq(['raw']) }

    it { should eq Infrastructure.for('aws') }
    it { should_not eq Infrastructure.for('openstack') }

    it 'has aws specific additional cloud properties' do
      expect(subject.additional_cloud_properties).to eq({'root_device_name' => '/dev/sda1'})
    end
  end

  describe Infrastructure::Google do
    its(:name)              { should eq('google') }
    its(:hypervisor)        { should eq('kvm') }
    its(:default_disk_size) { should eq(3072) }
    its(:disk_formats)      { should eq(['rawdisk']) }

    it { should eq Infrastructure.for('google') }
    it { should_not eq Infrastructure.for('openstack') }

    it 'has google specific additional cloud properties' do
      expect(subject.additional_cloud_properties).to eq({'root_device_name' => '/dev/sda1'})
    end
  end

  describe Infrastructure::OpenStack do
    its(:name)              { should eq('openstack') }
    its(:hypervisor)        { should eq('kvm') }
    its(:default_disk_size) { should eq(3072) }
    its(:disk_formats) {should eq(['qcow2', 'raw'])}

    it { should eq Infrastructure.for('openstack') }
    it { should_not eq Infrastructure.for('vsphere') }

    it 'has openstack specific additional cloud properties' do
      expect(subject.additional_cloud_properties).to eq({'auto_disk_config' => true})
    end
  end

  describe Infrastructure::Vsphere do
    its(:name)              { should eq('vsphere') }
    its(:hypervisor)        { should eq('esxi') }
    its(:default_disk_size) { should eq(3072) }
    its(:disk_formats)      { should eq(['ovf']) }

    it { should eq Infrastructure.for('vsphere') }
    it { should_not eq Infrastructure.for('aws') }

    it 'has vsphere specific additional cloud properties' do
      expect(subject.additional_cloud_properties).to eq({'root_device_name' => '/dev/sda1'})
    end
  end

  describe Infrastructure::Vcloud do
    its(:name)              { should eq('vcloud') }
    its(:hypervisor)        { should eq('esxi') }
    its(:default_disk_size) { should eq(3072) }
    its(:disk_formats)      { should eq(['ovf']) }

    it { should eq Infrastructure.for('vcloud') }
    it { should_not eq Infrastructure.for('vsphere') }

    it 'has vcloud specific additional cloud properties' do
      expect(subject.additional_cloud_properties).to eq({'root_device_name' => '/dev/sda1'})
    end
  end

  describe Infrastructure::Azure do
    its(:name)              { should eq('azure') }
    its(:hypervisor)        { should eq('hyperv') }
    its(:default_disk_size) { should eq(3072) }
    its(:disk_formats)      { should eq(['vhd']) }

    it { should eq Infrastructure.for('azure') }
    it { should_not eq Infrastructure.for('vcloud') }

    it 'has azure specific additional cloud properties' do
      expect(subject.additional_cloud_properties).to eq({'root_device_name' => '/dev/sda1'})
    end
  end

  describe Infrastructure::Softlayer do
    its(:name)              { should eq('softlayer') }
    its(:hypervisor)        { should eq('esxi') }
    its(:default_disk_size) { should eq(3072) }
    its(:disk_formats)      { should eq(['ovf']) }

    it { should eq Infrastructure.for('softlayer') }
    it { should_not eq Infrastructure.for('vsphere') }

    it 'has softlayer specific additional cloud properties' do
      expect(subject.additional_cloud_properties).to eq({'root_device_name' => '/dev/sda1'})
    end
  end
end
