require 'spec_helper'
require 'bosh/dev/pipeline'

module Bosh::Dev
  describe Pipeline do
    include FakeFS::SpecHelpers

    let(:fog_storage) { Fog::Storage.new(provider: 'AWS', aws_access_key_id: 'fake access key', aws_secret_access_key: 'fake secret key') }
    let(:pipeline_storage) { Bosh::Dev::PipelineStorage.new }

    let(:bucket_files) { fog_storage.directories.get('bosh-ci-pipeline').files }
    let(:bucket_name) { 'bosh-ci-pipeline' }
    let(:logger) { instance_double('Logger').as_null_object }
    let(:build_id) { '456' }
    let(:download_directory) { '/FAKE/CUSTOM/WORK/DIRECTORY' }

    subject(:pipeline) { Pipeline.new(storage: pipeline_storage, logger: logger, build_id: build_id) }

    before do
      Fog.mock!
      Fog::Mock.reset
      fog_storage.directories.create(key: bucket_name) if bucket_name
      ENV.stub(to_hash: {
        'AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT' => 'fake access key',
        'AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT' => 'fake secret key',
      })
    end

    its(:s3_url) { should eq('s3://bosh-ci-pipeline/456/') }
    its(:gems_dir_url) { should eq('https://s3.amazonaws.com/bosh-ci-pipeline/456/gems/') }

    describe '#initialize' do
      context 'when initialized without any dependencies' do
        subject(:pipeline) { Pipeline.new }

        before do
          Build.stub(candidate: instance_double('Build', number: '102948923'))
        end

        it 'uses a default logger to stdout' do
          Logger.should_receive(:new).with($stdout)
          pipeline
        end
      end
    end

    describe '#create' do
      let(:bucket) { fog_storage.directories.get(bucket_name) }

      it 'creates the specified file on the pipeline bucket' do
        pipeline.create(key: 'dest_dir/foo/bar/baz.txt', body: 'contents of baz', public: true)

        expect(bucket.files.map(&:key)).to include '456/dest_dir/foo/bar/baz.txt'
        expect(bucket.files.get('456/dest_dir/foo/bar/baz.txt').body).to eq('contents of baz')
        expect(bucket.files.get('456/dest_dir/foo/bar/baz.txt').public_url).not_to be_nil
      end

      it 'publicizes the bucket only when asked to' do
        logger.should_receive(:info).with('uploaded to s3://bosh-ci-pipeline/456/dest_dir/foo/bar/baz.txt')
        pipeline.create(key: 'dest_dir/foo/bar/baz.txt', body: 'contents of baz', public: false)

        expect(bucket.files.map(&:key)).to include '456/dest_dir/foo/bar/baz.txt'
        expect(bucket.files.get('456/dest_dir/foo/bar/baz.txt').public_url).to be_nil
      end

      context 'when the bucket does not exist' do
        let(:bucket_name) { false }

        it 'raises an error' do
          expect {
            pipeline.create(key: 'dest_dir/foo/bar/baz.txt', body: 'contents of baz', public: false)
          }.to raise_error("bucket 'bosh-ci-pipeline' not found")
        end
      end
    end

    describe '#s3_upload' do
      before do
        File.open('foobar-path', 'w') { |f| f.write('test data') }
      end

      it 'uploads the file to the specific path on the pipeline bucket' do
        logger.should_receive(:info).with('uploaded to s3://bosh-ci-pipeline/456/foo-bar-ubuntu.tgz')

        pipeline.s3_upload('foobar-path', 'foo-bar-ubuntu.tgz')
        expect(bucket_files.map(&:key)).to include '456/foo-bar-ubuntu.tgz'
        expect(bucket_files.get('456/foo-bar-ubuntu.tgz').body).to eq 'test data'
      end
    end

    describe '#publish_stemcell' do
      let(:stemcell) { instance_double('Bosh::Stemcell::Stemcell', light?: false, path: '/tmp/bosh-stemcell-aws-ubuntu.tgz', infrastructure: 'aws', name: 'bosh-stemcell') }

      before do
        FileUtils.mkdir('/tmp')
        File.open(stemcell.path, 'w') { |f| f.write(stemcell_contents) }
        logger.stub(:info)
      end

      describe 'when publishing a full stemcell' do
        let(:stemcell_contents) { 'contents of the stemcells' }
        let(:stemcell) { instance_double('Bosh::Stemcell::Stemcell', light?: false, path: '/tmp/bosh-stemcell-aws-ubuntu.tgz', infrastructure: 'aws', name: 'bosh-stemcell') }

        it 'publishes a stemcell to an S3 bucket' do
          logger.should_receive(:info).with('uploaded to s3://bosh-ci-pipeline/456/bosh-stemcell/aws/bosh-stemcell-aws-ubuntu.tgz')

          pipeline.publish_stemcell(stemcell)

          expect(bucket_files.map(&:key)).to include '456/bosh-stemcell/aws/bosh-stemcell-aws-ubuntu.tgz'
          expect(bucket_files.get('456/bosh-stemcell/aws/bosh-stemcell-aws-ubuntu.tgz').body).to eq 'contents of the stemcells'
        end

        it 'updates the latest stemcell in the S3 bucket' do
          logger.should_receive(:info).with('uploaded to s3://bosh-ci-pipeline/456/bosh-stemcell/aws/bosh-stemcell-latest-aws-xen-ubuntu.tgz')

          pipeline.publish_stemcell(stemcell)

          expect(bucket_files.map(&:key)).to include '456/bosh-stemcell/aws/bosh-stemcell-latest-aws-xen-ubuntu.tgz'
          expect(bucket_files.get('456/bosh-stemcell/aws/bosh-stemcell-latest-aws-xen-ubuntu.tgz').body).to eq 'contents of the stemcells'
        end
      end

      describe 'when publishing a light stemcell' do
        let(:stemcell_contents) { 'this file is a light stemcell' }
        let(:stemcell) { instance_double('Bosh::Stemcell::Stemcell', light?: true, path: '/tmp/light-bosh-stemcell-aws-ubuntu.tgz', infrastructure: 'aws', name: 'bosh-stemcell') }

        it 'publishes a light stemcell to S3 bucket' do
          pipeline.publish_stemcell(stemcell)

          expect(bucket_files.map(&:key)).to include '456/bosh-stemcell/aws/light-bosh-stemcell-aws-ubuntu.tgz'
          expect(bucket_files.get('456/bosh-stemcell/aws/light-bosh-stemcell-aws-ubuntu.tgz').body).to eq 'this file is a light stemcell'
        end

        it 'updates the latest light stemcell in the s3 bucket' do
          pipeline.publish_stemcell(stemcell)

          expect(bucket_files.map(&:key)).to include '456/bosh-stemcell/aws/light-bosh-stemcell-latest-aws-xen-ubuntu.tgz'
          expect(bucket_files.get('456/bosh-stemcell/aws/light-bosh-stemcell-latest-aws-xen-ubuntu.tgz').body).to eq 'this file is a light stemcell'
        end
      end
    end

    describe '#download_stemcell' do

      it 'downloads the specified stemcell version from the pipeline bucket' do
        pipeline_storage.should_receive(:download).with('bosh-ci-pipeline', '456/bosh-stemcell/aws', 'bosh-stemcell-456-aws-xen-ubuntu.tgz')
        pipeline.download_stemcell(infrastructure: Bosh::Stemcell::Infrastructure.for('aws'), name: 'bosh-stemcell', light: false)
      end

      context 'when remote file does not exist' do
        it 'raises' do
          stub_request(:get, 'http://bosh-ci-pipeline.s3.amazonaws.com/456/fooey/vsphere/fooey-456-vsphere-esxi-ubuntu.tgz').to_return(status: 404)

          expect {
            pipeline.download_stemcell(infrastructure: Bosh::Stemcell::Infrastructure.for('vsphere'), name: 'fooey', light: false)
          }.to raise_error("remote file '456/fooey/vsphere/fooey-456-vsphere-esxi-ubuntu.tgz' not found")
        end
      end

      it 'downloads the specified light stemcell version from the pipeline bucket' do
        logger.should_receive(:info).with("downloaded 's3://bosh-ci-pipeline/456/bosh-stemcell/aws/light-bosh-stemcell-456-aws-xen-ubuntu.tgz' -> 'light-bosh-stemcell-456-aws-xen-ubuntu.tgz'")

        pipeline_storage.should_receive(:download).with('bosh-ci-pipeline', '456/bosh-stemcell/aws', 'light-bosh-stemcell-456-aws-xen-ubuntu.tgz')
        pipeline.download_stemcell(infrastructure: Bosh::Stemcell::Infrastructure.for('aws'), name: 'bosh-stemcell', light: true)
      end

      it 'returns the name of the downloaded file' do
        options = {
          infrastructure: Bosh::Stemcell::Infrastructure.for('aws'),
          name: 'bosh-stemcell',
          light: true
        }

        pipeline_storage.should_receive(:download).with('bosh-ci-pipeline', '456/bosh-stemcell/aws', 'light-bosh-stemcell-456-aws-xen-ubuntu.tgz')
        expect(pipeline.download_stemcell(options)).to eq 'light-bosh-stemcell-456-aws-xen-ubuntu.tgz'
      end

    end

    describe '#bosh_stemcell_path' do
      let(:infrastructure) { Bosh::Stemcell::Infrastructure::Aws.new }

      it 'works' do
        expect(subject.bosh_stemcell_path(infrastructure, download_directory)).to eq(File.join(download_directory, 'light-bosh-stemcell-456-aws-xen-ubuntu.tgz'))
      end
    end

    describe '#micro_bosh_stemcell_path' do
      let(:infrastructure) { Bosh::Stemcell::Infrastructure::Vsphere.new }

      it 'works' do
        expect(subject.micro_bosh_stemcell_path(infrastructure, download_directory)).to eq(File.join(download_directory, 'micro-bosh-stemcell-456-vsphere-esxi-ubuntu.tgz'))
      end
    end

    describe '#cleanup_stemcells' do
      it 'removes stemcells created during the build' do
        FileUtils.mkdir_p(download_directory)
        FileUtils.touch(File.join(download_directory, 'foo-bosh-stemcell-bar-ubuntu.tgz'))
        FileUtils.touch(File.join(download_directory, 'foo-micro-bosh-stemcell-bar-ubuntu.tgz'))

        expect {
          subject.cleanup_stemcells(download_directory)
        }.to change { Dir.glob(File.join(download_directory, '*')) }.to([])
      end
    end
  end
end
