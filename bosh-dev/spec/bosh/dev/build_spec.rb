require 'spec_helper'
require 'bosh/dev/build'
require 'bosh/dev/pipeline'
require 'bosh/dev/micro_bosh_release'

module Bosh::Dev
  describe Build do
    let(:fake_s3_bucket) { 's3://FAKE_BOSH_CI_PIPELINE_BUCKET' }

    before do
      ENV.stub(:fetch).with('BUILD_NUMBER').and_return('current')
      ENV.stub(:fetch).with('CANDIDATE_BUILD_NUMBER').and_return('candidate')
      ENV.stub(:fetch).with('JOB_NAME').and_return('current_job')

      Bosh::Dev::Pipeline.any_instance.stub(base_url: fake_s3_bucket)
    end

    subject do
      Build.new(123)
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

    describe '#job_name' do
      its(:job_name) { should eq('current_job') }
    end

    describe '#upload' do
      let(:release) { double(MicroBoshRelease, tarball: 'release-tarball.tgz') }

      it 'uploads the release to the pipeline bucket with its build number' do
        Rake::FileUtilsExt.should_receive(:sh).with('s3cmd put release-tarball.tgz s3://FAKE_BOSH_CI_PIPELINE_BUCKET/release/bosh-123.tgz')
        subject.upload(release)
      end
    end
  end
end
