require 'spec_helper'
require 'bosh/dev/promotable_artifacts'
require 'bosh/dev/build'

module Bosh::Dev
  describe PromotableArtifacts do
    subject(:build_artifacts) { PromotableArtifacts.new(build) }
    let(:light_stemcell) { instance_double('Bosh::Stemcell::Archive') }
    let(:build) { instance_double('Bosh::Dev::Build', number: 123, light_stemcell: light_stemcell) }

    its(:release_file) { should eq('bosh-123.tgz') }

    describe '#all' do
      let(:stemcell_artifacts) { instance_double('Bosh::Dev::StemcellArtifacts', list: archive_filenames) }
      let(:archive_filenames) do
        [
          instance_double('Bosh::Stemcell::ArchiveFilename', to_s: 'blue/stemcell-blue.tgz'),
          instance_double('Bosh::Stemcell::ArchiveFilename', to_s: 'red/stemcell-red.tgz'),
        ]
      end

      let(:gem_components) do
        instance_double('Bosh::Dev::GemComponents', components: [
          'GemComponent 1',
          'GemComponent 2',
        ])
      end

      let(:gem_artifacts) do
        [
          instance_double('Bosh::Dev::GemArtifact', promote: nil),
          instance_double('Bosh::Dev::GemArtifact', promote: nil),
        ]
      end

      let(:light_stemcell_pointer) do
        instance_double('Bosh::Dev::LightStemcellPointer', promote: nil)
      end

      before do
        gem_artifact_klass = class_double('Bosh::Dev::GemArtifact').as_stubbed_const
        gem_artifact_klass.stub(:new).with(gem_components.components.first, 's3://bosh-ci-pipeline/123/', build.number).and_return(gem_artifacts.first)
        gem_artifact_klass.stub(:new).with(gem_components.components.last, 's3://bosh-ci-pipeline/123/', build.number).and_return(gem_artifacts.last)

        light_stemcell_pointer_klass = class_double('Bosh::Dev::LightStemcellPointer').as_stubbed_const
        light_stemcell_pointer_klass.stub(:new).with(light_stemcell).and_return(light_stemcell_pointer)

        get_component_klass = class_double('Bosh::Dev::GemComponents').as_stubbed_const
        get_component_klass.stub(:new).with(123).and_return(gem_components)

        stemcell_artifacts_klass = class_double('Bosh::Dev::StemcellArtifacts').as_stubbed_const
        stemcell_artifacts_klass.stub(:all).with(build.number).and_return(stemcell_artifacts)

        RakeFileUtils.stub(:sh)
      end

      it 'lists a command to promote the release' do
        RakeFileUtils.
          should_receive(:sh).
          with('s3cmd --verbose cp s3://bosh-ci-pipeline/123/release/bosh-123.tgz s3://bosh-jenkins-artifacts/release/bosh-123.tgz')

        build_artifacts.all.each { |artifact| artifact.promote }
      end

      it 'lists commands to promote gems' do
        expect(build_artifacts.all).to include(*gem_artifacts)
      end

      it 'lists commands to update the light stemcell pointer' do
        expect(build_artifacts.all).to include(*light_stemcell_pointer)
      end

      it 'lists commands to promote stemcell pipeline artifacts' do
        RakeFileUtils.
          should_receive(:sh).
          with('s3cmd --verbose cp s3://bosh-ci-pipeline/123/blue/stemcell-blue.tgz s3://bosh-jenkins-artifacts/blue/stemcell-blue.tgz')

        RakeFileUtils.
          should_receive(:sh).
          with('s3cmd --verbose cp s3://bosh-ci-pipeline/123/red/stemcell-red.tgz s3://bosh-jenkins-artifacts/red/stemcell-red.tgz')

        build_artifacts.all.each { |artifact| artifact.promote }
      end
    end
  end
end
