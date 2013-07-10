require 'spec_helper'
require 'bosh/dev/build'
require 'bosh/dev/pipeline'

module Bosh::Dev
  describe Build do
    let(:fake_s3_bucket) { 's3://FAKE_BOSH_CI_PIPELINE_BUCKET' }

    before do
      ENV.stub(:fetch).with('BUILD_NUMBER').and_return('current')
      ENV.stub(:fetch).with('CANDIDATE_BUILD_NUMBER').and_return('candidate')
      ENV.stub(:fetch).with('JOB_NAME').and_return('current_job')

      Bosh::Dev::Pipeline.any_instance.stub(base_url: fake_s3_bucket)
    end

    describe '.current' do
      subject do
        Build.current
      end

      its(:s3_release_url) { should eq(File.join(fake_s3_bucket, 'release/bosh-current.tgz')) }
    end

    describe '.candidate' do
      subject do
        Build.candidate
      end

      its(:s3_release_url) { should eq(File.join(fake_s3_bucket, 'release/bosh-candidate.tgz')) }
    end

    describe '.job_name' do
      subject do
        Build.candidate
      end

      its(:job_name) { should eq('current_job') }
    end
  end
end
