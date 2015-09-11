require 'spec_helper'
require 'bosh/dev/release_artifact'

module Bosh::Dev
  describe ReleaseArtifact do
    let(:build_number) { 'fake-build-number' }

    subject(:release_artifact) { ReleaseArtifact.new(build_number, logger) }

    describe '#name' do
      it 'returns the filename for the release' do
        expect(release_artifact.name).to eq("bosh-#{build_number}.tgz")
      end
    end

    describe '#promote' do
      let(:source) { 'fake-release-source' }
      let(:destination) { 'fake-release-destination' }

      before do
        allow(UriProvider).to receive(:pipeline_s3_path).
          with('fake-build-number/release', release_artifact.name).
          and_return(source)

        allow(UriProvider).to receive(:artifacts_s3_path).
          with('release', release_artifact.name).
          and_return(destination)
      end

      it 'copies the release from the pipeline to the artifacts bucket' do
        expect(Open3).to receive(:capture3).
          with("s3cmd --verbose cp #{source} #{destination}").
          and_return([ nil, nil, instance_double('Process::Status', success?: true) ])

        release_artifact.promote
      end
    end

    describe '#promoted?' do
      let(:destination) { 'fake-release-destination' }

      before do
        allow(UriProvider).to receive(:artifacts_s3_path).
          with('release', release_artifact.name).
          and_return(destination)
      end

      it 'returns true if the release file exists in the s3 bucket' do
        expect(Open3).to receive(:capture3).
          with("s3cmd info #{destination}").
          and_return([ nil, nil, instance_double('Process::Status', success?: true) ])

        expect(release_artifact.promoted?).to be(true)
      end

      it 'returns false if the release file does not exists in the s3 bucket' do
        expect(Open3).to receive(:capture3).
          with("s3cmd info #{destination}").
          and_return([ nil, 'fake-error', instance_double('Process::Status', success?: false) ])

        expect(release_artifact.promoted?).to be(false)
      end
    end
  end
end
