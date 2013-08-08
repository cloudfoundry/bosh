require 'spec_helper'
require 'bosh/dev/build'

module Bosh::Dev
  describe Build do
    include FakeFS::SpecHelpers

    let(:job_name) { 'current_job' }
    let(:download_directory) { '/FAKE/CUSTOM/WORK/DIRECTORY' }
    let(:access_key_id) { 'FAKE_ACCESS_KEY_ID' }
    let(:secret_access_key) { 'FAKE_SECRET_ACCESS_KEY' }
    let(:fog_storage) do
      Fog::Storage.new(provider: 'AWS',
                       aws_access_key_id: access_key_id,
                       aws_secret_access_key: secret_access_key)
    end

    subject(:build) { Build.new(123) }

    before(:all) do
      Fog.mock!
    end

    before do
      Fog::Mock.reset
      fog_storage.directories.create(key: 'bosh-ci-pipeline')

      ENV.stub(:to_hash).and_return(
        'BUILD_NUMBER' => 'current',
        'CANDIDATE_BUILD_NUMBER' => 'candidate',
        'AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT' => secret_access_key,
        'AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT' => access_key_id,
        'JOB_NAME' => job_name
      )
    end

    after(:all) do
      Fog.unmock!
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

    its(:s3_release_url) { should eq(File.join('s3://bosh-ci-pipeline/123/release/bosh-123.tgz')) }

    describe '#job_name' do
      its(:job_name) { should eq('current_job') }
    end

    describe '#upload' do
      let(:release) { double(tarball: 'release-tarball.tgz') }
      let(:upload_adapter) { instance_double('Bosh::Dev::UploadAdapter') }
      let(:io) { double }

      it 'uploads the release with its build number' do
        File.stub(:open).with(release.tarball) { io }
        upload_adapter.should_receive(:upload).with(bucket_name: 'bosh-ci-pipeline', key: '123/release/bosh-123.tgz', body: io, public: true)

        subject.upload(release, upload_adapter: upload_adapter)
      end

      context 'when the file does not exist' do

        it 'raises an error' do
          expect { subject.upload(release, upload_adapter: upload_adapter) }.to raise_error(Errno::ENOENT)
        end

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

    its(:gems_dir_url) { should eq('https://s3.amazonaws.com/bosh-ci-pipeline/123/gems/') }

    describe '#promote_artifacts' do
      it 'syncs buckets and updates AWS aim text reference' do
        subject.should_receive(:sync_buckets)
        subject.should_receive(:update_light_micro_bosh_ami_pointer_file).
          with(access_key_id: 'FAKE_ACCESS_KEY_ID', secret_access_key: 'FAKE_SECRET_ACCESS_KEY')

        subject.promote_artifacts(access_key_id: 'FAKE_ACCESS_KEY_ID', secret_access_key: 'FAKE_SECRET_ACCESS_KEY')
      end
    end

    describe '#sync_buckets' do
      before do
        Rake::FileUtilsExt.stub(:sh)
      end

      it 'syncs the pipeline gems' do
        Rake::FileUtilsExt.should_receive(:sh).
          with('s3cmd --verbose sync s3://bosh-ci-pipeline/123/gems/ s3://bosh-jenkins-gems')

        subject.sync_buckets
      end

      it 'syncs the releases' do
        Rake::FileUtilsExt.should_receive(:sh).
          with('s3cmd --verbose sync s3://bosh-ci-pipeline/123/release s3://bosh-jenkins-artifacts')

        subject.sync_buckets
      end

      it 'syncs the bosh stemcells' do
        Rake::FileUtilsExt.should_receive(:sh).
          with('s3cmd --verbose sync s3://bosh-ci-pipeline/123/bosh-stemcell s3://bosh-jenkins-artifacts')

        subject.sync_buckets
      end

      it 'syncs the micro bosh stemcells' do
        Rake::FileUtilsExt.should_receive(:sh).
          with('s3cmd --verbose sync s3://bosh-ci-pipeline/123/micro-bosh-stemcell s3://bosh-jenkins-artifacts')

        subject.sync_buckets
      end
    end

    describe '#update_light_micro_bosh_ami_pointer_file' do
      let(:fake_stemcell_filename) { 'FAKE_STEMCELL_FILENAME' }
      let(:fake_stemcell) { instance_double('Bosh::Stemcell::Stemcell') }
      let(:infrastructure) { instance_double('Bosh::Stemcell::Infrastructure::Base', name: 'aws') }
      let(:archive_filename) { instance_double('Bosh::Stemcell::ArchiveFilename', to_s: fake_stemcell_filename) }

      before do
        Bosh::Stemcell::Infrastructure.stub(:for).with('aws').and_return(infrastructure)

        Bosh::Stemcell::ArchiveFilename.stub(:new).and_return(archive_filename)

        fake_stemcell.stub(ami_id: 'FAKE_AMI_ID')
        Bosh::Stemcell::Stemcell.stub(new: fake_stemcell)

        stub_request(:get, 'http://bosh-ci-pipeline.s3.amazonaws.com/123/micro-bosh-stemcell/aws/FAKE_STEMCELL_FILENAME')
      end

      it 'downloads the aws micro-bosh-stemcell for the current build' do
        subject.should_receive(:download_stemcell).
          with(infrastructure: infrastructure, name: 'micro-bosh-stemcell', light: true)

        subject.update_light_micro_bosh_ami_pointer_file(access_key_id: access_key_id, secret_access_key: secret_access_key)
      end

      it 'initializes a Stemcell with the downloaded stemcell filename' do
        Bosh::Stemcell::ArchiveFilename.should_receive(:new).
          with('123', infrastructure, 'micro-bosh-stemcell', true).and_return(archive_filename)

        Bosh::Stemcell::Stemcell.should_receive(:new).with(fake_stemcell_filename)

        subject.update_light_micro_bosh_ami_pointer_file(access_key_id: access_key_id, secret_access_key: secret_access_key)
      end

      it 'updates the S3 object with the AMI ID from the stemcell.MF' do
        fake_stemcell.stub(ami_id: 'FAKE_AMI_ID')

        subject.update_light_micro_bosh_ami_pointer_file(access_key_id: access_key_id, secret_access_key: secret_access_key)

        expect(fog_storage.
                 directories.get('bosh-jenkins-artifacts').
                 files.get('last_successful_micro-bosh-stemcell-aws_ami_us-east-1').body).to eq('FAKE_AMI_ID')
      end

      it 'is publicly reachable' do
        subject.update_light_micro_bosh_ami_pointer_file(access_key_id: access_key_id, secret_access_key: secret_access_key)

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

    describe '#upload_stemcell' do
      let(:stemcell) { instance_double('Bosh::Stemcell::Stemcell', light?: false, path: '/tmp/bosh-stemcell-aws-ubuntu.tgz', infrastructure: 'aws', name: 'bosh-stemcell') }
      let(:logger) { instance_double('Logger').as_null_object }
      let(:bucket_files) { fog_storage.directories.get('bosh-ci-pipeline').files }

      before do
        FileUtils.mkdir('/tmp')
        File.open(stemcell.path, 'w') { |f| f.write(stemcell_contents) }
        Logger.stub(new: logger)
      end

      describe 'when publishing a full stemcell' do
        let(:stemcell_contents) { 'contents of the stemcells' }
        let(:stemcell) { instance_double('Bosh::Stemcell::Stemcell', light?: false, path: '/tmp/bosh-stemcell-aws-ubuntu.tgz', infrastructure: 'aws', name: 'bosh-stemcell') }

        it 'publishes a stemcell to an S3 bucket' do
          logger.should_receive(:info).with('uploaded to s3://bosh-ci-pipeline/123/bosh-stemcell/aws/bosh-stemcell-aws-ubuntu.tgz')

          build.upload_stemcell(stemcell)

          expect(bucket_files.map(&:key)).to include '123/bosh-stemcell/aws/bosh-stemcell-aws-ubuntu.tgz'
          expect(bucket_files.get('123/bosh-stemcell/aws/bosh-stemcell-aws-ubuntu.tgz').body).to eq 'contents of the stemcells'
        end

        it 'updates the latest stemcell in the S3 bucket' do
          logger.should_receive(:info).with('uploaded to s3://bosh-ci-pipeline/123/bosh-stemcell/aws/bosh-stemcell-latest-aws-xen-ubuntu.tgz')

          build.upload_stemcell(stemcell)

          expect(bucket_files.map(&:key)).to include '123/bosh-stemcell/aws/bosh-stemcell-latest-aws-xen-ubuntu.tgz'
          expect(bucket_files.get('123/bosh-stemcell/aws/bosh-stemcell-latest-aws-xen-ubuntu.tgz').body).to eq 'contents of the stemcells'
        end
      end

      describe 'when publishing a light stemcell' do
        let(:stemcell_contents) { 'this file is a light stemcell' }
        let(:stemcell) { instance_double('Bosh::Stemcell::Stemcell', light?: true, path: '/tmp/light-bosh-stemcell-aws-ubuntu.tgz', infrastructure: 'aws', name: 'bosh-stemcell') }

        it 'publishes a light stemcell to S3 bucket' do
          build.upload_stemcell(stemcell)

          expect(bucket_files.map(&:key)).to include '123/bosh-stemcell/aws/light-bosh-stemcell-aws-ubuntu.tgz'
          expect(bucket_files.get('123/bosh-stemcell/aws/light-bosh-stemcell-aws-ubuntu.tgz').body).to eq 'this file is a light stemcell'
        end

        it 'updates the latest light stemcell in the s3 bucket' do
          build.upload_stemcell(stemcell)

          expect(bucket_files.map(&:key)).to include '123/bosh-stemcell/aws/light-bosh-stemcell-latest-aws-xen-ubuntu.tgz'
          expect(bucket_files.get('123/bosh-stemcell/aws/light-bosh-stemcell-latest-aws-xen-ubuntu.tgz').body).to eq 'this file is a light stemcell'
        end
      end
    end

    describe '#download_stemcell' do
      let(:download_adapter) { instance_double('Bosh::Dev::DownloadAdapter') }

      context 'when not specifying a download directory' do

        it 'downloads the specified stemcell version from the pipeline bucket' do
          download_adapter.should_receive(:download).with(URI('http://bosh-ci-pipeline.s3.amazonaws.com/123/bosh-stemcell/aws/bosh-stemcell-123-aws-xen-ubuntu.tgz'), '/bosh-stemcell-123-aws-xen-ubuntu.tgz')
          build.download_stemcell(infrastructure: Bosh::Stemcell::Infrastructure.for('aws'), name: 'bosh-stemcell', light: false, download_adapter: download_adapter)
        end

        context 'when remote file does not exist' do
          it 'raises' do
            download_adapter.stub(:download).and_raise 'hell'

            expect {
              build.download_stemcell(infrastructure: Bosh::Stemcell::Infrastructure.for('vsphere'), name: 'fooey', light: false, download_adapter: download_adapter)
            }.to raise_error 'hell'
          end
        end

        it 'downloads the specified light stemcell version from the pipeline bucket' do
          download_adapter.should_receive(:download).with(URI('http://bosh-ci-pipeline.s3.amazonaws.com/123/bosh-stemcell/aws/light-bosh-stemcell-123-aws-xen-ubuntu.tgz'), '/light-bosh-stemcell-123-aws-xen-ubuntu.tgz')
          build.download_stemcell(infrastructure: Bosh::Stemcell::Infrastructure.for('aws'), name: 'bosh-stemcell', light: true, download_adapter: download_adapter)
        end

        it 'returns the name of the downloaded file' do
          options = {
            infrastructure: Bosh::Stemcell::Infrastructure.for('aws'),
            name: 'bosh-stemcell',
            light: true,
            download_adapter: download_adapter
          }

          download_adapter.should_receive(:download).with(URI('http://bosh-ci-pipeline.s3.amazonaws.com/123/bosh-stemcell/aws/light-bosh-stemcell-123-aws-xen-ubuntu.tgz'), '/light-bosh-stemcell-123-aws-xen-ubuntu.tgz')
          expect(build.download_stemcell(options)).to eq 'light-bosh-stemcell-123-aws-xen-ubuntu.tgz'
        end
      end

      context 'when specifying a download directory' do

        it 'downloads the specified stemcell version from the pipeline bucket' do
          download_adapter.should_receive(:download).with(URI('http://bosh-ci-pipeline.s3.amazonaws.com/123/bosh-stemcell/aws/bosh-stemcell-123-aws-xen-ubuntu.tgz'), '/a/b/c/bosh-stemcell-123-aws-xen-ubuntu.tgz')
          build.download_stemcell(infrastructure: Bosh::Stemcell::Infrastructure.for('aws'), name: 'bosh-stemcell', light: false, download_adapter: download_adapter, output_directory: '/a/b/c')
        end

      end

    end

    describe '#bosh_stemcell_path' do
      let(:infrastructure) { Bosh::Stemcell::Infrastructure::Aws.new }

      it 'works' do
        expect(subject.bosh_stemcell_path(infrastructure, download_directory)).to eq(File.join(download_directory, 'light-bosh-stemcell-123-aws-xen-ubuntu.tgz'))
      end
    end

    describe '#micro_bosh_stemcell_path' do
      let(:infrastructure) { Bosh::Stemcell::Infrastructure::Vsphere.new }

      it 'works' do
        expect(subject.micro_bosh_stemcell_path(infrastructure, download_directory)).to eq(File.join(download_directory, 'micro-bosh-stemcell-123-vsphere-esxi-ubuntu.tgz'))
      end
    end
  end
end
