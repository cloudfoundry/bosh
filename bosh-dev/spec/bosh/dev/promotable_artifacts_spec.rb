require 'spec_helper'
require 'bosh/dev/promotable_artifacts'
require 'bosh/dev/build'

module Bosh::Dev
  describe PromotableArtifacts do
    subject(:build_artifacts) { PromotableArtifacts.new(build, logger) }
    let(:build) { instance_double('Bosh::Dev::Build', number: 123) }

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

      it 'includes promotable release artifacts' do
        stemcell_artifact_list.each { |artifact| expect(artifact).to receive(:promote) }

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
  end
end
