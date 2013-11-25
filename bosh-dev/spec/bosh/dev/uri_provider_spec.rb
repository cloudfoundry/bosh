require 'spec_helper'
require 'bosh/dev/uri_provider'

describe Bosh::Dev::UriProvider do
  describe '.pipeline_uri' do
    it 'returns a uri object relative to the Bosh pipeline base URI' do
      Bosh::Dev::UriProvider.pipeline_uri('foo/bar', 'baz.bat').should == URI('http://bosh-ci-pipeline.s3.amazonaws.com/foo/bar/baz.bat')
    end
  end

  describe '.artifacts_uri' do
    it 'returns a uri object relative to the Bosh artifacts base URI' do
      Bosh::Dev::UriProvider.artifacts_uri('foo/bar', 'baz.bat').should == URI('http://bosh-jenkins-artifacts.s3.amazonaws.com/foo/bar/baz.bat')
    end
  end
end
