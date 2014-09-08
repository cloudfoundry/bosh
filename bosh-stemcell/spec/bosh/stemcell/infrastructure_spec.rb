require 'spec_helper'
require 'bosh/stemcell/infrastructure'

module Bosh::Stemcell
  describe Infrastructure do
    describe '.for' do
      it 'returns the correct infrastrcture' do
        expect(Infrastructure.for('openstack')).to be_an(Infrastructure::OpenStack)
        expect(Infrastructure.for('aws')).to be_an(Infrastructure::Aws)
        expect(Infrastructure.for('vsphere')).to be_a(Infrastructure::Vsphere)
        expect(Infrastructure.for('warden')).to be_a(Infrastructure::Warden)
        expect(Infrastructure.for('vcloud')).to be_a(Infrastructure::Vcloud)
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
    end
  end

  describe Infrastructure::Aws do
    its(:name)              { should eq('aws') }
    its(:hypervisor)        { should eq('xen') }
    its(:default_disk_size) { should eq(2048) }

    it { should eq Infrastructure.for('aws') }
    it { should_not eq Infrastructure.for('openstack') }
  end

  describe Infrastructure::OpenStack do
    its(:name)              { should eq('openstack') }
    its(:hypervisor)        { should eq('kvm') }
    its(:default_disk_size) { should eq(3072) }

    it { should eq Infrastructure.for('openstack') }
    it { should_not eq Infrastructure.for('vsphere') }
  end

  describe Infrastructure::Vsphere do
    its(:name)              { should eq('vsphere') }
    its(:hypervisor)        { should eq('esxi') }
    its(:default_disk_size) { should eq(3072) }

    it { should eq Infrastructure.for('vsphere') }
    it { should_not eq Infrastructure.for('aws') }
  end

  describe Infrastructure::Vcloud do
    its(:name)              { should eq('vcloud') }
    its(:hypervisor)        { should eq('esxi') }
    its(:default_disk_size) { should eq(3072) }
  end
end
