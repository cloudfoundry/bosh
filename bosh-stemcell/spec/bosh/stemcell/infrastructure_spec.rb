require 'spec_helper'
require 'bosh/stemcell/infrastructure'

module Bosh::Stemcell
  describe Infrastructure do
    describe '.for' do
      it 'returns the correct infrastrcture' do
        expect(Infrastructure.for('openstack')).to be_an(Infrastructure::OpenStack)
        expect(Infrastructure.for('aws')).to be_an(Infrastructure::Aws)
        expect(Infrastructure.for('vsphere')).to be_a(Infrastructure::Vsphere)
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

    it 'defaults to not supporting light stemcells' do
      infrastructure = Infrastructure::Base.new(name: 'foo', hypervisor: 'bar', default_disk_size: 1024)
      expect(infrastructure).not_to be_light
    end

    describe '.all' do

      it 'returns all the infrastructure subclasses' do
        expected_classes = [
          Bosh::Stemcell::Infrastructure::Vsphere,
          Bosh::Stemcell::Infrastructure::Aws,
          Bosh::Stemcell::Infrastructure::OpenStack
        ].to_set

        classes = Infrastructure.all.map(&:class).to_set
        expect(expected_classes).to eq(classes)
      end

    end

    describe Infrastructure::Aws do
      its(:name) { should eq('aws') }
      it { should be_light }
      its(:hypervisor) { should eq('xen') }
      its(:default_disk_size) { should eq(2048) }
    end

    describe Infrastructure::OpenStack do
      its(:name) { should eq('openstack') }
      it { should_not be_light }
      its(:hypervisor) { should eq('kvm') }
      its(:default_disk_size) { should eq(10240) }
    end

    describe Infrastructure::Vsphere do
      its(:name) { should eq('vsphere') }
      it { should_not be_light }
      its(:hypervisor) { should eq('esxi') }
      its(:default_disk_size) { should eq(2048) }
    end
  end
end
