require 'spec_helper'
require 'bosh/dev/promotable_artifacts'
require 'bosh/dev/build'

module Bosh::Dev
  describe PromotableArtifacts do
    subject(:build_artifacts) { PromotableArtifacts.new(build, logger, skip_artifacts: skipped_artifacts) }
    let(:build) { instance_double('Bosh::Dev::Build', number: 123) }
    let(:skipped_artifacts) { [] }

    it 'should be constructable without options' do
      expect { PromotableArtifacts.new(build, logger) }.to_not raise_error
    end

    its(:release_file) { should eq('bosh-123.tgz') }

    describe '#all' do
      let(:gem_components) do
        instance_double('Bosh::Dev::GemComponents', components: [
          'GemComponent 1',
          'GemComponent 2',
        ])
      end

      before do
        allow(Bosh::Dev::GemComponents).to receive(:new).with(123).and_return(gem_components)
      end

      let(:gem_artifacts) do
        [
          instance_double('Bosh::Dev::GemArtifact', promote: nil),
          instance_double('Bosh::Dev::GemArtifact', promote: nil),
        ]
      end

      before do
        allow(Bosh::Dev::GemArtifact).to receive(:new).with(gem_components.components[0], 's3://bosh-ci-pipeline/123/', build.number, logger).and_return(gem_artifacts[0])
        allow(Bosh::Dev::GemArtifact).to receive(:new).with(gem_components.components[1], 's3://bosh-ci-pipeline/123/', build.number, logger).and_return(gem_artifacts[1])
      end

      let(:release_artifact) { instance_double('Bosh::Dev::ReleaseArtifact', promote: nil) }

      before do
        allow(Bosh::Dev::ReleaseArtifact).to receive(:new).with(build.number, logger).and_return(release_artifact)
      end

      let(:stemcell_artifacts) { instance_double('Bosh::Dev::StemcellArtifacts', list: stemcell_artifact_list) }
      let(:stemcell_artifact_list) do
        [
          instance_double('Bosh::Dev::StemcellArtifact', promote: nil),
          instance_double('Bosh::Dev::StemcellArtifact', promote: nil),
        ]
      end

      before do
        allow(Bosh::Dev::StemcellArtifacts).to receive(:all).with(build.number, logger).and_return(stemcell_artifacts)
      end

      context 'when no artifacts are skipped' do
        let(:skipped_artifacts) { [] }

        it 'includes promotable release artifacts' do
          expect(release_artifact).to receive(:promote)

          build_artifacts.all.each { |artifact| artifact.promote }
        end

        it 'includes promotable gem artifacts' do
          gem_artifacts.each { |artifact| expect(artifact).to receive(:promote) }

          build_artifacts.all.each { |artifact| artifact.promote }
        end

        it 'includes promotable stemcell artifacts' do
          stemcell_artifact_list.each { |artifact| expect(artifact).to receive(:promote) }

          build_artifacts.all.each { |artifact| artifact.promote }
        end
      end

      context 'when skipping gems and the release' do
        let(:skipped_artifacts) { ['gems', 'release'] }

        it 'does not include promotable release artifacts' do
          expect(release_artifact).to_not receive(:promote)

          build_artifacts.all.each { |artifact| artifact.promote }
        end

        it 'does not include promotable gem artifacts' do
          gem_artifacts.each { |artifact| expect(artifact).to_not receive(:promote) }

          build_artifacts.all.each { |artifact| artifact.promote }
        end

        it 'includes promotable stemcell artifacts' do
          stemcell_artifact_list.each { |artifact| expect(artifact).to receive(:promote) }

          build_artifacts.all.each { |artifact| artifact.promote }
        end
      end

      context 'when skipping stemcell' do
        let(:skipped_artifacts) { ['stemcells'] }

        it 'includes promotable release artifacts' do
          expect(release_artifact).to receive(:promote)

          build_artifacts.all.each { |artifact| artifact.promote }
        end

        it 'includes promotable gem artifacts' do
          gem_artifacts.each { |artifact| expect(artifact).to receive(:promote) }

          build_artifacts.all.each { |artifact| artifact.promote }
        end

        it 'does not include promotable stemcell artifacts' do
          stemcell_artifact_list.each { |artifact| expect(artifact).to_not receive(:promote) }

          build_artifacts.all.each { |artifact| artifact.promote }
        end
      end

      context 'when trying to skip and artifact that does not exist' do
        it 'tells you that you are doing it wrong' do
          expect { PromotableArtifacts.new(build, logger, skip_artifacts: [:nopes]) }.to raise_error
        end
      end
    end
  end
end
