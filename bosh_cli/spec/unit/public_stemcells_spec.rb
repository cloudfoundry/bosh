require 'spec_helper'
require 'cli/public_stemcells'

module Bosh::Cli
  describe PublicStemcells, vcr: { cassette_name: 'promoted-stemcells' } do
    subject(:public_stemcells) { PublicStemcells.new }

    describe '#has_stemcell?' do
      it { should have_stemcell('bosh-stemcell-1001-aws-xen-ubuntu.tgz') }
      it { should_not have_stemcell('bosh-stemcell-1001-aws-xen-solaris.tgz') }
    end

    describe '#find' do
      subject(:find) { public_stemcells.find('bosh-stemcell-1001-aws-xen-ubuntu.tgz') }

      it { should be_a(PublicStemcell) }
      its(:name) { should eq('bosh-stemcell-1001-aws-xen-ubuntu.tgz') }
      its(:size) { should eq(384139128) }
    end

    describe '#all' do
      subject(:list_of_stemcells) { public_stemcells.all.map(&:name) }

      it 'returns all promoted bosh-stemcells' do
        expect(list_of_stemcells.size).to eq(573)
      end

      it 'returns the most recent aws stemcells' do
        expect(list_of_stemcells).to include('bosh-stemcell-1341-aws-xen-ubuntu.tgz')
        expect(list_of_stemcells).to include('light-bosh-stemcell-1341-aws-xen-ubuntu.tgz')
      end

      it 'returns the most recent openstack stemcells' do
        expect(list_of_stemcells).to include('bosh-stemcell-1341-openstack-kvm-ubuntu.tgz')
      end

      it 'returns the most recent vsphere stemcells' do
        expect(list_of_stemcells).to include('bosh-stemcell-1341-vsphere-esxi-ubuntu.tgz')
        expect(list_of_stemcells).to include('bosh-stemcell-1341-vsphere-esxi-centos.tgz')
      end

      it 'returns legacy stemcells' do
        expect(list_of_stemcells).to include('bosh-stemcell-aws-0.6.4.tgz')
      end

      it 'excludes stemcells with "latest" as their version because these keep changing' do
        expect(list_of_stemcells).not_to include('latest')
      end
    end

    describe '#recent' do
      subject(:list_of_stemcells) do
        public_stemcells.recent.map(&:name)
      end

      it 'returns the most recent of each variety of stemcell, except legacy stemcells' do
        expect(list_of_stemcells).to eq %w[
                                          bosh-stemcell-1365-aws-xen-ubuntu.tgz
                                          light-bosh-stemcell-1365-aws-xen-ubuntu.tgz
                                          bosh-stemcell-1365-openstack-kvm-ubuntu.tgz
                                          bosh-stemcell-1365-vsphere-esxi-ubuntu.tgz
                                          bosh-stemcell-1365-vsphere-esxi-centos.tgz
                                        ]
      end

      it 'excludes stemcells with "latest" as their version because these keep changing' do
        expect(list_of_stemcells).not_to include('latest')
      end
    end
  end
end
