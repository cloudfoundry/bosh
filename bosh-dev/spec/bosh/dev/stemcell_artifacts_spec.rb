require 'spec_helper'
require 'bosh/dev/stemcell_artifacts'

module Bosh::Dev
  describe StemcellArtifacts do
    describe '.all' do
      it 'returns pipepline artifacts with all infrastructures for ubuntu and vsphere centos' do
        artifacts = instance_double('Bosh::Dev::StemcellArtifacts')

        described_class.should_receive(:new) do |version, matrix|
          expect(version).to eq('version')
          expect(matrix.size).to eq(6)

          expect(matrix[0].map(&:name)).to eq(%w(vsphere   ubuntu))
          expect(matrix[1].map(&:name)).to eq(%w(vsphere   centos))
          expect(matrix[2].map(&:name)).to eq(%w(aws       ubuntu))
          expect(matrix[3].map(&:name)).to eq(%w(aws       centos))
          expect(matrix[4].map(&:name)).to eq(%w(openstack ubuntu))
          expect(matrix[5].map(&:name)).to eq(%w(openstack centos))

          artifacts
        end

        described_class.all('version').should == artifacts
      end
    end

    describe '#list' do
      subject(:artifacts) { described_class.new(version, matrix) }
      let(:version)       { 123 }
      let(:matrix)        { [[infrastructure1, operating_system1], [infrastructure2, operating_system2]] }

      let(:infrastructure1)   { instance_double('Bosh::Stemcell::Infrastructure::Base', name: 'fake-infrastructure-name1', light?: false) }
      let(:operating_system1) { instance_double('Bosh::Stemcell::OperatingSystem::Base', name: 'fake-operating-system-name1') }

      let(:infrastructure2)   { instance_double('Bosh::Stemcell::Infrastructure::Base', name: 'fake-infrastructure-name2', light?: false) }
      let(:operating_system2) { instance_double('Bosh::Stemcell::OperatingSystem::Base', name: 'fake-operating-system-name2') }

      it 'returns a complete list of stemcell build artifact names' do
        Bosh::Stemcell::ArchiveFilename.stub(:new)
          .with('latest', infrastructure1, operating_system1, 'bosh-stemcell', false)
          .and_return('fake-latest-archive-filename1')

        Bosh::Stemcell::ArchiveFilename.stub(:new)
          .with(version, infrastructure1, operating_system1, 'bosh-stemcell', false)
          .and_return('fake-version-archive-filename1')

        Bosh::Stemcell::ArchiveFilename.stub(:new)
          .with('latest', infrastructure2, operating_system2, 'bosh-stemcell', false)
          .and_return('fake-latest-archive-filename2')

        Bosh::Stemcell::ArchiveFilename.stub(:new)
          .with(version, infrastructure2, operating_system2, 'bosh-stemcell', false)
          .and_return('fake-version-archive-filename2')

        expect(artifacts.list.sort).to eq(%w[
          bosh-stemcell/fake-infrastructure-name1/fake-version-archive-filename1
          bosh-stemcell/fake-infrastructure-name1/fake-latest-archive-filename1
          bosh-stemcell/fake-infrastructure-name2/fake-version-archive-filename2
          bosh-stemcell/fake-infrastructure-name2/fake-latest-archive-filename2
        ].sort)
      end

      it 'returns artifact filenames for both light and regular stemcells' do
        infrastructure1.stub(light?: true)

        Bosh::Stemcell::ArchiveFilename.stub(:new).and_return('unrelated')

        Bosh::Stemcell::ArchiveFilename.stub(:new)
          .with(version, infrastructure1, operating_system1, 'bosh-stemcell', false)
          .and_return('fake-version-archive-filename')
        Bosh::Stemcell::ArchiveFilename.stub(:new)
          .with(version, infrastructure1, operating_system1, 'bosh-stemcell', true)
          .and_return('fake-light-version-archive-filename')

        Bosh::Stemcell::ArchiveFilename.stub(:new)
          .with('latest', infrastructure1, operating_system1, 'bosh-stemcell', false)
          .and_return('fake-latest-archive-filename')
        Bosh::Stemcell::ArchiveFilename.stub(:new)
          .with('latest', infrastructure1, operating_system1, 'bosh-stemcell', true)
          .and_return('fake-light-latest-archive-filename')

        expect(artifacts.list).to include('bosh-stemcell/fake-infrastructure-name1/fake-version-archive-filename')
        expect(artifacts.list).to include('bosh-stemcell/fake-infrastructure-name1/fake-light-version-archive-filename')
        expect(artifacts.list).to include('bosh-stemcell/fake-infrastructure-name1/fake-latest-archive-filename')
        expect(artifacts.list).to include('bosh-stemcell/fake-infrastructure-name1/fake-light-latest-archive-filename')
      end
    end
  end
end
