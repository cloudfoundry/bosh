require 'spec_helper'
require 'bosh/dev/uri_provider'

describe Bosh::Dev::UriProvider do
  describe '.pipeline_uri' do
    it 'returns a http uri object relative to the Bosh pipeline base URI' do
      expect(Bosh::Dev::UriProvider.pipeline_uri('foo/bar', 'baz.bat')).to eq(URI('http://bosh-ci-pipeline.s3.amazonaws.com/foo/bar/baz.bat'))
    end
  end

  describe '.pipeline_s3_path' do
    it 'returns a s3 uri string relative to the Bosh pipeline bucket' do
      expect(Bosh::Dev::UriProvider.pipeline_s3_path('foo/bar', 'baz.bat')).to eq('s3://bosh-ci-pipeline/foo/bar/baz.bat')
    end
  end

  describe '.artifacts_uri' do
    it 'returns a uri object relative to the Bosh artifacts base URI' do
      expect(Bosh::Dev::UriProvider.artifacts_uri('foo/bar', 'baz.bat')).to eq(URI('http://bosh-jenkins-artifacts.s3.amazonaws.com/foo/bar/baz.bat'))
    end
  end

  describe '.artifacts_s3_path' do
    it 'returns a uri object relative to the Bosh artifacts base URI' do
      expect(Bosh::Dev::UriProvider.artifacts_s3_path('foo/bar', 'baz.bat')).to eq('s3://bosh-jenkins-artifacts/foo/bar/baz.bat')
    end

    context 'when given path has leading slash' do
      it 'does not double up on the slash' do
        expect(Bosh::Dev::UriProvider.artifacts_s3_path('/foo/bar', 'baz.bat')).to eq('s3://bosh-jenkins-artifacts/foo/bar/baz.bat')
      end
    end
  end

  describe '.release_patches_uri' do
    context 'when a remote directory path is provided' do
      it 'returns a uri object relative to the Bosh release patches base URI' do
        expect(Bosh::Dev::UriProvider.release_patches_uri('foo/bar', 'baz.bat')).to eq(URI('http://bosh-jenkins-release-patches.s3.amazonaws.com/foo/bar/baz.bat'))
      end
    end

    context 'when the remote directory path is empty' do
      it 'returns a uri object relative to the Bosh release patches base URI' do
        expect(Bosh::Dev::UriProvider.release_patches_uri('', 'baz.bat')).to eq(URI('http://bosh-jenkins-release-patches.s3.amazonaws.com/baz.bat'))
      end
    end
  end
end
