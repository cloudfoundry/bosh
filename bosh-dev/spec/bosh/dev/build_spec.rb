require 'spec_helper'
require 'bosh/dev/build'

module Bosh::Dev
  describe Build do
    include FakeFS::SpecHelpers

    let(:fake_pipeline) { instance_double('Bosh::Dev::Pipeline', s3_url: 's3://FAKE_BOSH_CI_PIPELINE_BUCKET/') }
    let(:job_name) { 'current_job' }

    subject { Build.new(123) }

    before do
      ENV.stub(:to_hash).and_return(
        'BUILD_NUMBER' => 'current',
        'CANDIDATE_BUILD_NUMBER' => 'candidate',
        'JOB_NAME' => job_name
      )

      Bosh::Dev::Pipeline.stub(new: fake_pipeline)
    end

    describe '.candidate' do
      subject do
        Build.candidate
      end

      context 'when running the "publish_candidate_gems" job' do
        let(:job_name) { 'publish_candidate_gems' }

        its(:number) { should eq 'current' }
      end

      context 'when running the jobs downstream to "publish_candidate_gems"' do
        before do
          ENV.stub(:fetch).with('JOB_NAME').and_return('something_that_needs_candidates')
        end

        its(:number) { should eq 'candidate' }
      end
    end

    its(:s3_release_url) { should eq(File.join(fake_pipeline.s3_url, 'release/bosh-123.tgz')) }

    describe '#job_name' do
      its(:job_name) { should eq('current_job') }
    end

    describe '#upload' do
      let(:release) { double(tarball: 'release-tarball.tgz') }

      it 'uploads the release to the pipeline bucket with its build number' do
        fake_pipeline.should_receive(:s3_upload).with('release-tarball.tgz', 'release/bosh-123.tgz')

        subject.upload(release)
      end
    end

    describe '#download_release' do
      before do
        Rake::FileUtilsExt.stub(sh: true)
      end

      it 'downloads the release' do
        Rake::FileUtilsExt.should_receive(:sh).
          with("s3cmd --verbose -f get #{subject.s3_release_url} release/bosh-#{subject.number}.tgz").and_return(true)

        subject.download_release
      end

      it 'returns the path of the downloaded release' do
        expect(subject.download_release).to eq("release/bosh-#{subject.number}.tgz")
      end

      context 'when download fails' do
        it 'raises an error' do
          Rake::FileUtilsExt.stub(sh: false)

          expect {
            subject.download_release
          }.to raise_error(RuntimeError, "Command failed: s3cmd --verbose -f get #{subject.s3_release_url} release/bosh-#{subject.number}.tgz")
        end
      end

    end

    describe '#promote_artifacts' do
      it 'syncs buckets and updates AWS aim text reference' do
        subject.should_receive(:sync_buckets)
        subject.should_receive(:update_light_micro_bosh_ami_pointer_file).
          with('FAKE_ACCESS_KEY_ID', 'FAKE_SECRET_ACCESS_KEY')

        subject.promote_artifacts(access_key_id: 'FAKE_ACCESS_KEY_ID', secret_access_key: 'FAKE_SECRET_ACCESS_KEY')
      end
    end

    describe '#sync_buckets' do
      before do
        Rake::FileUtilsExt.stub(:sh)
      end

      it 'syncs the pipeline gems' do
        Rake::FileUtilsExt.should_receive(:sh).
          with('s3cmd --verbose sync s3://FAKE_BOSH_CI_PIPELINE_BUCKET/gems/ s3://bosh-jenkins-gems')

        subject.sync_buckets
      end

      it 'syncs the releases' do
        Rake::FileUtilsExt.should_receive(:sh).
          with('s3cmd --verbose sync s3://FAKE_BOSH_CI_PIPELINE_BUCKET/release s3://bosh-jenkins-artifacts')

        subject.sync_buckets
      end

      it 'syncs the bosh stemcells' do
        Rake::FileUtilsExt.should_receive(:sh).
          with('s3cmd --verbose sync s3://FAKE_BOSH_CI_PIPELINE_BUCKET/bosh-stemcell s3://bosh-jenkins-artifacts')

        subject.sync_buckets
      end

      it 'syncs the micro bosh stemcells' do
        Rake::FileUtilsExt.should_receive(:sh).
          with('s3cmd --verbose sync s3://FAKE_BOSH_CI_PIPELINE_BUCKET/micro-bosh-stemcell s3://bosh-jenkins-artifacts')

        subject.sync_buckets
      end
    end

    describe '#update_light_micro_bosh_ami_pointer_file' do
      let(:access_key_id) { 'FAKE_ACCESS_KEY_ID' }
      let(:secret_access_key) { 'FAKE_SECRET_ACCESS_KEY' }

      let(:fog_storage) do
        Fog::Storage.new(provider: 'AWS',
                         aws_access_key_id: access_key_id,
                         aws_secret_access_key: secret_access_key)
      end
      let(:fake_stemcell_filename) { 'FAKE_STEMCELL_FILENAME' }
      let(:fake_stemcell) { instance_double('Bosh::Stemcell::Stemcell') }
      let(:infrastructure) { instance_double('Bosh::Dev::Infrastructure') }

      before(:all) do
        Fog.mock!
      end

      before do
        Fog::Mock.reset

        Infrastructure.stub(:for).with('aws').and_return(infrastructure)

        fake_pipeline.stub(:download_stemcell)
        fake_pipeline.stub(:stemcell_filename)

        fake_stemcell.stub(ami_id: 'FAKE_AMI_ID')
        Bosh::Stemcell::Stemcell.stub(new: fake_stemcell)
      end

      after(:all) do
        Fog.unmock!
      end

      it 'downloads the aws micro-bosh-stemcell for the current build' do
        fake_pipeline.should_receive(:download_stemcell).
          with('123', infrastructure: infrastructure, name: 'micro-bosh-stemcell', light: true)

        subject.update_light_micro_bosh_ami_pointer_file(access_key_id, secret_access_key)
      end

      it 'initializes a Stemcell with the downloaded stemcell filename' do
        fake_pipeline.should_receive(:stemcell_filename).
          with('123', infrastructure, 'micro-bosh-stemcell', true).and_return(fake_stemcell_filename)

        Bosh::Stemcell::Stemcell.should_receive(:new).with(fake_stemcell_filename)

        subject.update_light_micro_bosh_ami_pointer_file(access_key_id, secret_access_key)
      end

      it 'updates the S3 object with the AMI ID from the stemcell.MF' do
        fake_stemcell.stub(ami_id: 'FAKE_AMI_ID')

        subject.update_light_micro_bosh_ami_pointer_file(access_key_id, secret_access_key)

        expect(fog_storage.
                 directories.get('bosh-jenkins-artifacts').
                 files.get('last_successful_micro-bosh-stemcell-aws_ami_us-east-1').body).to eq('FAKE_AMI_ID')
      end

      it 'is publicly reachable' do
        subject.update_light_micro_bosh_ami_pointer_file(access_key_id, secret_access_key)

        expect(fog_storage.
                 directories.get('bosh-jenkins-artifacts').
                 files.get('last_successful_micro-bosh-stemcell-aws_ami_us-east-1').public_url).to_not be_nil
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
  end
end
