require 'spec_helper'
require 'bosh/dev/stemcell_artifacts'

module Bosh::Dev
  describe StemcellArtifacts do
    describe '.all' do
      context 'when BOSH_PROMOTE_STEMCELLS are specified' do
        before do
          stub_const('ENV', {
            'BOSH_PROMOTE_STEMCELLS' => 'vsphere-ubuntu-centos,aws-ubuntu-centos,openstack-ubuntu-centos',
          })
        end

        it 'returns pipeline artifacts with specified stemcells' do
          artifacts = instance_double('Bosh::Dev::StemcellArtifacts')

          expect(described_class).to receive(:new) do |version, definitions|
            expect(version).to eq('version')

            matrix = definitions.map { |d| [d.infrastructure.name, d.operating_system.name, d.operating_system.version, d.agent.name] }
            expect(matrix).to eq([
              ['vsphere', 'centos', nil, 'go'],
              ['aws', 'centos', nil, 'go'],
              ['openstack', 'centos', nil, 'go'],
            ])

            artifacts
          end

          expect(described_class.all('version')).to eq(artifacts)
        end
      end

      context 'when BOSH_PROMOTE_STEMCELLS is empty' do
        before do
          stub_const('ENV', {'BOSH_PROMOTE_STEMCELLS' => ''})
        end

        it 'returns no pipeline artifacts' do
          artifacts = instance_double('Bosh::Dev::StemcellArtifacts')

          expect(described_class).to receive(:new) do |version, definitions|
            expect(version).to eq('version')
            expect(definitions).to be_empty

            artifacts
          end

          expect(described_class.all('version')).to eq(artifacts)
        end
      end

      context 'when BOSH_PROMOTE_STEMCELLS are not specified' do
        before do
          stub_const('ENV', {})
        end

        it 'returns pipeline artifacts with all infrastructures for ubuntu and vsphere centos' do
          artifacts = instance_double('Bosh::Dev::StemcellArtifacts')

          expect(described_class).to receive(:new) do |version, definitions|
            expect(version).to eq('version')

            matrix = definitions.map { |d| [d.infrastructure.name, d.operating_system.name, d.operating_system.version, d.agent.name] }
            expect(matrix).to eq([
              %w(vsphere ubuntu lucid go),
              %w(vsphere ubuntu trusty go),
              ['vsphere', 'centos', nil, 'go'],
              %w(aws ubuntu lucid go),
              %w(aws ubuntu trusty go),
              ['aws', 'centos', nil, 'go'],
              %w(openstack ubuntu trusty go),
              ['openstack', 'centos', nil, 'go'],
            ])

            artifacts
          end

          expect(described_class.all('version')).to eq(artifacts)
        end
      end
    end

    describe '#list' do
      subject(:artifacts) { described_class.new(version, definitions) }
      let(:version) { 123 }
      let(:definitions) do
        [
          Bosh::Stemcell::Definition.for('vsphere', 'ubuntu', 'lucid', 'go'),
          Bosh::Stemcell::Definition.for('openstack', 'centos', nil, 'go'),
        ]
      end

      it 'returns a complete list of stemcell build artifact names' do
        allow(Bosh::Stemcell::ArchiveFilename).to receive(:new)
          .with('latest', definitions[0], 'bosh-stemcell', false)
          .and_return('fake-latest-archive-filename1')

        allow(Bosh::Stemcell::ArchiveFilename).to receive(:new)
          .with(version, definitions[0], 'bosh-stemcell', false)
          .and_return('fake-version-archive-filename1')

        allow(Bosh::Stemcell::ArchiveFilename).to receive(:new)
          .with('latest', definitions[1], 'bosh-stemcell', false)
          .and_return('fake-latest-archive-filename2')

        allow(Bosh::Stemcell::ArchiveFilename).to receive(:new)
          .with(version, definitions[1], 'bosh-stemcell', false)
          .and_return('fake-version-archive-filename2')

        expect(artifacts.list.sort).to eq(%w[
          bosh-stemcell/vsphere/fake-version-archive-filename1
          bosh-stemcell/vsphere/fake-latest-archive-filename1
          bosh-stemcell/openstack/fake-version-archive-filename2
          bosh-stemcell/openstack/fake-latest-archive-filename2
        ].sort)
      end

      context 'when definition includes aws' do
        let(:definitions) do
          [
            Bosh::Stemcell::Definition.for('aws', 'ubuntu', 'lucid', 'go')
          ]
        end

        it 'returns artifact filenames for both light and regular stemcells' do
          allow(Bosh::Stemcell::ArchiveFilename).to receive(:new).and_return('unrelated')

          allow(Bosh::Stemcell::ArchiveFilename).to receive(:new)
            .with(version, definitions[0], 'bosh-stemcell', false)
            .and_return('fake-version-archive-filename')
          allow(Bosh::Stemcell::ArchiveFilename).to receive(:new)
            .with(version, definitions[0], 'bosh-stemcell', true)
            .and_return('fake-light-version-archive-filename')

          allow(Bosh::Stemcell::ArchiveFilename).to receive(:new)
            .with('latest', definitions[0], 'bosh-stemcell', false)
            .and_return('fake-latest-archive-filename')
          allow(Bosh::Stemcell::ArchiveFilename).to receive(:new)
            .with('latest', definitions[0], 'bosh-stemcell', true)
            .and_return('fake-light-latest-archive-filename')

          expect(artifacts.list.length).to eq 4
          expect(artifacts.list).to include('bosh-stemcell/aws/fake-version-archive-filename')
          expect(artifacts.list).to include('bosh-stemcell/aws/fake-light-version-archive-filename')
          expect(artifacts.list).to include('bosh-stemcell/aws/fake-latest-archive-filename')
          expect(artifacts.list).to include('bosh-stemcell/aws/fake-light-latest-archive-filename')
        end
      end
    end
  end
end
