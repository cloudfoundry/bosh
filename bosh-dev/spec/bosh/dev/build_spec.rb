require 'spec_helper'
require 'bosh/dev/build'
require 'bosh/dev/pipeline'
require 'bosh/dev/micro_bosh_release'

module Bosh::Dev
  describe Build do
    let(:fake_s3_bucket) { 'FAKE_BOSH_CI_PIPELINE_BUCKET' }

    before do
      ENV.stub(:fetch).with('BUILD_NUMBER').and_return('current')
      ENV.stub(:fetch).with('CANDIDATE_BUILD_NUMBER').and_return('candidate')
      ENV.stub(:fetch).with('JOB_NAME').and_return('current_job')

      Bosh::Dev::Pipeline.any_instance.stub(bucket: fake_s3_bucket)
    end

    subject do
      Build.new(123)
    end

    describe '.current' do
      subject do
        Build.current
      end

      its(:s3_release_url) { should eq(File.join('s3://', fake_s3_bucket, 'release/bosh-current.tgz')) }
    end

    describe '.candidate' do
      subject do
        Build.candidate
      end

      its(:s3_release_url) { should eq(File.join('s3://', fake_s3_bucket, 'release/bosh-candidate.tgz')) }
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

    describe '#sync_buckets' do
      before do
        Rake::FileUtilsExt.stub(:sh)
      end

      it 'syncs the pipeline gems' do
        Rake::FileUtilsExt.should_receive(:sh).
            with('s3cmd sync s3://bosh-ci-pipeline/gems/ s3://bosh-jenkins-gems')

        subject.sync_buckets
      end

      it 'syncs the releases' do
        Rake::FileUtilsExt.should_receive(:sh).
            with('s3cmd sync s3://bosh-ci-pipeline/release s3://bosh-jenkins-artifacts')

        subject.sync_buckets
      end

      it 'syncs the bosh stemcells' do
        Rake::FileUtilsExt.should_receive(:sh).
            with('s3cmd sync s3://bosh-ci-pipeline/bosh-stemcell s3://bosh-jenkins-artifacts')

        subject.sync_buckets
      end

      it 'syncs the micro bosh stemcells' do
        Rake::FileUtilsExt.should_receive(:sh).
            with('s3cmd sync s3://bosh-ci-pipeline/micro-bosh-stemcell s3://bosh-jenkins-artifacts')

        subject.sync_buckets
      end
    end
  end
end
