require 'spec_helper'
require 'cli/public_stemcells'

module Bosh::Cli
  describe PublicStemcells, vcr: { cassette_name: 'promoted-stemcells' } do
    subject(:public_stemcells) do
      PublicStemcells.new
    end

    describe '#has_stemcell?' do
      it { should have_stemcell('bosh-stemcell-1001-aws-xen-ubuntu.tgz') }
      it { should_not have_stemcell('bosh-stemcell-1001-aws-xen-solaris.tgz') }
    end

    describe '#find' do
      subject(:find) do
        public_stemcells.find('bosh-stemcell-1001-aws-xen-ubuntu.tgz')
      end

      it { should be_a(PublicStemcells::PublicStemcell) }
      its(:name) { should eq('bosh-stemcell-1001-aws-xen-ubuntu.tgz') }
      its(:size) { should eq(384139128) }
    end

    describe '#all' do
      subject(:list_of_stemcells) do
        public_stemcells.all.map(&:name)
      end

      it 'returns all promoted bosh-stemcells' do
        expect(list_of_stemcells).to have(557).stemcells
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

      it 'excludes stemcells with "latest" as their version because these keep changing' do
        expect(list_of_stemcells).not_to include('latest')
      end
    end

    describe '#recent' do
      subject(:list_of_stemcells) do
        public_stemcells.recent.map(&:name)
      end

      it 'returns the most recent of each variety of stemcell' do
        expect(list_of_stemcells).to eq %w[
                                          bosh-stemcell-1341-aws-xen-ubuntu.tgz
                                          light-bosh-stemcell-1341-aws-xen-ubuntu.tgz
                                          bosh-stemcell-1341-openstack-kvm-ubuntu.tgz
                                          bosh-stemcell-1341-vsphere-esxi-ubuntu.tgz
                                          bosh-stemcell-1341-vsphere-esxi-centos.tgz
                                        ]
      end

      it 'excludes stemcells with "latest" as their version because these keep changing' do
        expect(list_of_stemcells).not_to include('latest')
      end
    end
  end

  describe PublicStemcells::PublicStemcell do
    subject(:public_stemcell) do
      PublicStemcells::PublicStemcell.new('bosh-stemcell/aws/bosh-stemcell-1341-aws-xen-ubuntu.tgz', 383487957)
    end

    its(:name) { should eq('bosh-stemcell-1341-aws-xen-ubuntu.tgz') }
    its(:version) { should eq(1341) }
    its(:url) { should eq('https://bosh-jenkins-artifacts.s3.amazonaws.com/bosh-stemcell/aws/bosh-stemcell-1341-aws-xen-ubuntu.tgz')}
    its(:size) { should eq(383487957)}
  end
end
