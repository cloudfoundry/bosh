require 'spec_helper'
require 'cli/public_stemcells'

module Bosh::Cli
  describe PublicStemcells, vcr: { cassette_name: 'promoted-stemcells' } do
    subject(:public_stemcells) { PublicStemcells.new }

    describe '#has_stemcell?' do
      it { is_expected.to have_stemcell('bosh-stemcell-1001-aws-xen-ubuntu.tgz') }
      it { is_expected.not_to have_stemcell('bosh-stemcell-1001-aws-xen-solaris.tgz') }
    end

    describe '#find' do
      subject(:find) { public_stemcells.find('bosh-stemcell-1001-aws-xen-ubuntu.tgz') }

      it { is_expected.to be_a(PublicStemcell) }
      its(:name) { is_expected.to eq('bosh-stemcell-1001-aws-xen-ubuntu.tgz') }
      its(:size) { is_expected.to eq(384139128) }
    end

    describe '#all' do
      subject(:list_of_stemcells) { public_stemcells.all.map(&:name) }

      it 'returns all promoted bosh-stemcells' do
        expect(list_of_stemcells.size).to eq(968)
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
        expect(list_of_stemcells).to eq %w[bosh-stemcell-2416-aws-xen-ubuntu.tgz
                                          bosh-stemcell-2416-aws-xen-centos.tgz
                                          bosh-stemcell-2416-aws-xen-centos-go_agent.tgz
                                          bosh-stemcell-2416-aws-xen-ubuntu-go_agent.tgz
                                          light-bosh-stemcell-2416-aws-xen-ubuntu.tgz
                                          light-bosh-stemcell-2416-aws-xen-centos.tgz
                                          light-bosh-stemcell-2416-aws-xen-centos-go_agent.tgz
                                          light-bosh-stemcell-2416-aws-xen-ubuntu-go_agent.tgz
                                          bosh-stemcell-2416-openstack-kvm-ubuntu.tgz
                                          bosh-stemcell-2416-openstack-kvm-centos.tgz
                                          bosh-stemcell-2416-vsphere-esxi-ubuntu.tgz
                                          bosh-stemcell-2416-vsphere-esxi-centos.tgz
                                          bosh-stemcell-2416-vsphere-esxi-centos-go_agent.tgz
                                          bosh-stemcell-2416-vsphere-esxi-ubuntu-go_agent.tgz
                                          bosh-stemcell-53-warden-boshlite-ubuntu.tgz
                                          ]
      end

      it 'excludes stemcells with "latest" as their version because these keep changing' do
        expect(list_of_stemcells).not_to include('latest')
      end
    end
  end
end
