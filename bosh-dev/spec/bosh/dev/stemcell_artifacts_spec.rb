require 'spec_helper'
require 'bosh/dev/stemcell_artifacts'

module Bosh::Dev
  describe StemcellArtifacts do
    describe '.all' do
      context 'when BOSH_PROMOTE_STEMCELLS are specified' do
        before do
          stub_const('ENV', {
            'BOSH_PROMOTE_STEMCELLS' => 'vsphere-esxi-centos,aws-xen-centos,openstack-kvm-centos',
          })
        end

        it 'returns pipeline artifacts with specified stemcells' do
          artifacts = instance_double('Bosh::Dev::StemcellArtifacts')

          expect(described_class).to receive(:new) do |version, definitions, logger|
            expect(version).to eq('version')

            matrix = definitions.map { |d| [d.infrastructure.name, d.hypervisor_name, d.operating_system.name, d.operating_system.version, d.agent.name] }
            expect(matrix).to eq([
              ['vsphere', 'esxi', 'centos', '7', 'go'],
              ['aws', 'xen', 'centos', '7', 'go'],
              ['openstack', 'kvm', 'centos', '7', 'go'],
            ])

            expect(logger).to eq(logger)

            artifacts
          end

          expect(described_class.all('version', logger)).to eq(artifacts)
        end
      end

      context 'when BOSH_PROMOTE_STEMCELLS is empty' do
        before do
          stub_const('ENV', {'BOSH_PROMOTE_STEMCELLS' => ''})
        end

        it 'returns no pipeline artifacts' do
          artifacts = instance_double('Bosh::Dev::StemcellArtifacts')

          expect(described_class).to receive(:new) do |version, definitions, logger|
            expect(version).to eq('version')
            expect(definitions).to be_empty
            expect(logger).to eq(logger)

            artifacts
          end

          expect(described_class.all('version', logger)).to eq(artifacts)
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

            matrix = definitions.map { |d| [d.infrastructure.name, d.hypervisor_name, d.operating_system.name, d.operating_system.version, d.agent.name, d.light?] }
            expect(matrix).to eq([
              ['vsphere', 'esxi', 'ubuntu', 'trusty', 'go', false],
              ['vsphere', 'esxi', 'centos', '7', 'go', false],
              ['vcloud', 'esxi', 'ubuntu', 'trusty', 'go', false],
              ['aws', 'xen', 'ubuntu', 'trusty', 'go', true],
              ['aws', 'xen', 'ubuntu', 'trusty', 'go', false],
              ['aws', 'xen', 'centos', '7', 'go', true],
              ['aws', 'xen', 'centos', '7', 'go', false],
              ['aws', 'xen-hvm', 'ubuntu', 'trusty', 'go', true],
              ['aws', 'xen-hvm', 'centos', '7', 'go', true],
              ['openstack', 'kvm', 'ubuntu', 'trusty', 'go', false],
              ['openstack', 'kvm', 'centos', '7', 'go', false],
            ])

            artifacts
          end

          expect(described_class.all('version', logger)).to eq(artifacts)
        end
      end
    end

    describe '#list' do
      subject(:artifacts) { described_class.new(version, definitions, logger) }
      let(:version) { 123 }
      let(:definitions) do
        [
          Bosh::Stemcell::Definition.for('vsphere', 'esxi', 'ubuntu', 'trusty', 'go', false),
          Bosh::Stemcell::Definition.for('openstack', 'kvm', 'centos', '7', 'go', false),
        ]
      end

      it 'returns a complete list of stemcell build artifact names' do
        stemcell_artifact1_version = instance_double('Bosh::Dev::StemcellArtifact')
        expect(StemcellArtifact).to receive(:new)
          .with(version, version, definitions[0], logger, 'ovf')
          .and_return(stemcell_artifact1_version)

        stemcell_artifact1_latest = instance_double('Bosh::Dev::StemcellArtifact')
        expect(StemcellArtifact).to receive(:new)
          .with(version, 'latest', definitions[0], logger, 'ovf')
          .and_return(stemcell_artifact1_latest)

        stemcell_artifact2_version_qcow = instance_double('Bosh::Dev::StemcellArtifact')
        expect(StemcellArtifact).to receive(:new)
          .with(version, version, definitions[1], logger, 'qcow2')
          .and_return(stemcell_artifact2_version_qcow)

        stemcell_artifact2_latest_qcow = instance_double('Bosh::Dev::StemcellArtifact')
        expect(StemcellArtifact).to receive(:new)
          .with(version, 'latest', definitions[1], logger, 'qcow2')
          .and_return(stemcell_artifact2_latest_qcow)

        stemcell_artifact2_version_raw = instance_double('Bosh::Dev::StemcellArtifact')
        expect(StemcellArtifact).to receive(:new)
          .with(version, version, definitions[1], logger, 'raw')
          .and_return(stemcell_artifact2_version_raw)

        stemcell_artifact2_latest_raw = instance_double('Bosh::Dev::StemcellArtifact')
        expect(StemcellArtifact).to receive(:new)
          .with(version, 'latest', definitions[1], logger, 'raw')
          .and_return(stemcell_artifact2_latest_raw)

        expect(artifacts.list).to eq([
          stemcell_artifact1_version,
          stemcell_artifact1_latest,
          stemcell_artifact2_version_qcow,
          stemcell_artifact2_latest_qcow,
          stemcell_artifact2_version_raw,
          stemcell_artifact2_latest_raw,
        ])
      end
    end
  end
end
