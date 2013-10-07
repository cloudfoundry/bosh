require 'spec_helper'
require 'bosh/dev/promote_artifacts'
require 'bosh/dev/build'

module Bosh::Dev
  describe PromoteArtifacts do
    subject(:build_artifacts) { PromoteArtifacts.new(build) }
    let(:build) { instance_double('Bosh::Dev::Build', number: 123) }

    its(:destination)  { should eq('s3://bosh-jenkins-artifacts') }
    its(:source)       { should eq('s3://bosh-ci-pipeline/123/') }
    its(:release_file) { should eq('bosh-123.tgz') }

    describe '#commands' do
      let(:pipeline_artifacts) { instance_double('Bosh::Dev::PipelineArtifacts', list: archive_filenames) }
      let(:archive_filenames) do
        [
          instance_double('Bosh::Stemcell::ArchiveFilename', to_s: 'blue/stemcell-blue.tgz'),
          instance_double('Bosh::Stemcell::ArchiveFilename', to_s: 'red/stemcell-red.tgz'),
        ]
      end

      before do
        pipeline_artifacts_klass = class_double('Bosh::Dev::PipelineArtifacts').as_stubbed_const
        pipeline_artifacts_klass.stub(:all).with(build.number).and_return(pipeline_artifacts)
      end

      it 'lists a command to promote the release' do
        expect(build_artifacts.commands).to include(
          's3cmd --verbose cp s3://bosh-ci-pipeline/123/release/bosh-123.tgz s3://bosh-jenkins-artifacts/release/bosh-123.tgz')
      end

      it 'lists commands to promote gems' do
        expect(build_artifacts.commands).to include(
          's3cmd --verbose sync s3://bosh-ci-pipeline/123/gems/ s3://bosh-jenkins-gems')
      end

      it 'lists commands to promote stemcell pipeline artifacts' do
        expect(build_artifacts.commands).to include(
          's3cmd --verbose cp s3://bosh-ci-pipeline/123/blue/stemcell-blue.tgz s3://bosh-jenkins-artifacts/blue/stemcell-blue.tgz',
          's3cmd --verbose cp s3://bosh-ci-pipeline/123/red/stemcell-red.tgz s3://bosh-jenkins-artifacts/red/stemcell-red.tgz',
        )
      end
    end
  end
end
