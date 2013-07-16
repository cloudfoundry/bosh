require 'spec_helper'
require 'fakefs/spec_helpers'

require 'bosh/dev/build'
require 'bosh/dev/micro_bosh_release'
require 'bosh/dev/pipeline'
require 'bosh/dev/stemcell'

require 'fog'

module Bosh::Dev
  describe Build do
    include FakeFS::SpecHelpers

    let(:fake_s3_bucket) { 'FAKE_BOSH_CI_PIPELINE_BUCKET' }
    let(:fake_pipeline) { instance_double('Bosh::Dev::Pipeline') }

    before do
      ENV.stub(:fetch).with('BUILD_NUMBER').and_return('current')
      ENV.stub(:fetch).with('CANDIDATE_BUILD_NUMBER').and_return('candidate')
      ENV.stub(:fetch).with('JOB_NAME').and_return('current_job')

      fake_pipeline.stub(bucket: fake_s3_bucket)

      Bosh::Dev::Pipeline.stub(new: fake_pipeline)
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
        fake_pipeline.should_receive(:s3_upload).with('release-tarball.tgz', 'release/bosh-123.tgz')

        subject.upload(release)
      end
    end

    describe '#sync_buckets' do
      before do
        Rake::FileUtilsExt.stub(:sh)
      end

      it 'syncs the pipeline gems' do
        Rake::FileUtilsExt.should_receive(:sh).
            with('s3cmd sync s3://FAKE_BOSH_CI_PIPELINE_BUCKET/gems s3://bosh-jenkins-gems')

        subject.sync_buckets
      end

      it 'syncs the releases' do
        Rake::FileUtilsExt.should_receive(:sh).
            with('s3cmd sync s3://FAKE_BOSH_CI_PIPELINE_BUCKET/release s3://bosh-jenkins-artifacts')

        subject.sync_buckets
      end

      it 'syncs the bosh stemcells' do
        Rake::FileUtilsExt.should_receive(:sh).
            with('s3cmd sync s3://FAKE_BOSH_CI_PIPELINE_BUCKET/bosh-stemcell s3://bosh-jenkins-artifacts')

        subject.sync_buckets
      end

      it 'syncs the micro bosh stemcells' do
        Rake::FileUtilsExt.should_receive(:sh).
            with('s3cmd sync s3://FAKE_BOSH_CI_PIPELINE_BUCKET/micro-bosh-stemcell s3://bosh-jenkins-artifacts')

        subject.sync_buckets
      end
    end

    describe '#fog_storage' do
      it 'configures Fog::Storage correctly' do
        Fog::Storage.should_receive(:new).with(provider: 'AWS',
                                               aws_access_key_id: 'FAKE_ACCESS_KEY_ID',
                                               aws_secret_access_key: 'FAKE_SECRET_ACCESS_KEY')

        subject.fog_storage('FAKE_ACCESS_KEY_ID', 'FAKE_SECRET_ACCESS_KEY')
      end
    end

    describe '#update_light_micro_bosh_ami_pointer_file' do
      let(:aws_credentials) do
        {
            access_key_id: 'FAKE_ACCESS_KEY_ID',
            secret_access_key: 'FAKE_SECRET_ACCESS_KEY'
        }
      end
      let(:fog_storage) do
        Fog::Storage.new(provider: 'AWS',
                         aws_access_key_id: aws_credentials[:access_key_id],
                         aws_secret_access_key: aws_credentials[:secret_access_key])
      end
      let(:fake_stemcell_filename) { 'FAKE_STEMCELL_FILENAME' }
      let(:fake_stemcell) { instance_double('Bosh::Dev::Stemcell') }

      before(:all) do
        Fog.mock!
      end

      before do
        Fog::Mock.reset

        fake_pipeline.stub(:download_latest_stemcell)
        fake_pipeline.stub(:latest_stemcell_filename)

        fake_stemcell.stub(ami_id: 'FAKE_AMI_ID')
        Bosh::Dev::Stemcell.stub(new: fake_stemcell)
      end

      after(:all) do
        Fog.unmock!
      end

      it 'downloads the latest-micro-bosh-stemcell-aws' do
        fake_pipeline.should_receive(:download_latest_stemcell).
            with(infrastructure: 'aws', name: 'micro-bosh-stemcell', light: true)

        subject.update_light_micro_bosh_ami_pointer_file(aws_credentials)
      end

      it 'initializes a Stemcell with the downloaded stemcell filename' do
        fake_pipeline.should_receive(:latest_stemcell_filename).
            with('aws', 'micro-bosh-stemcell', true).and_return(fake_stemcell_filename)

        Bosh::Dev::Stemcell.should_receive(:new).with(fake_stemcell_filename)

        subject.update_light_micro_bosh_ami_pointer_file(aws_credentials)
      end

      it 'updates the S3 object with the AMI ID from the stemcell.MF' do
        fake_stemcell.stub(ami_id: 'FAKE_AMI_ID')

        subject.update_light_micro_bosh_ami_pointer_file(aws_credentials)

        expect(fog_storage.
                   directories.get('bosh-jenkins-artifacts').
                   files.get('last_successful_micro-bosh-stemcell-aws_ami_us-east-1').body).to eq('FAKE_AMI_ID')
      end

      it 'is publicly reachable' do
        subject.update_light_micro_bosh_ami_pointer_file(aws_credentials)

        expect(fog_storage.
                   directories.get('bosh-jenkins-artifacts').
                   files.get('last_successful_micro-bosh-stemcell-aws_ami_us-east-1').public_url).to_not be_nil
      end
    end
  end
end
